"""Digest of the subagent transcripts that worked on one task.

Usage: python3 -I transcripts.py <workspace> <project> <TASK-ID>

Finds subagent transcripts under ~/.claude/projects/*/*/subagents/ whose first
prompt names .agents/tasks/<project>/<TASK-ID>/, then prints per transcript:
agent type, round, tool call counts, failed calls, and repeated searches.
Transcripts are large; this digest is what task-retro reads instead of them.
"""
import glob
import json
import os
import re
import sys
from collections import Counter

SEARCH_TOOLS = {"Grep", "Glob", "Read"}
SEARCH_BASH = re.compile(r"^\s*(cd [^;&]+(&&|;)\s*)?(grep|rg|find|ls|cat|sed -n|head|tail)\b")


def first_prompt(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            if rec.get("type") != "user":
                continue
            content = rec.get("message", {}).get("content")
            if isinstance(content, str):
                return content
            if isinstance(content, list):
                return " ".join(c.get("text", "") for c in content if isinstance(c, dict))
    return ""


def short(value, limit=140):
    text = value if isinstance(value, str) else json.dumps(value, ensure_ascii=True)
    text = " ".join(text.split())
    return text if len(text) <= limit else text[: limit - 3] + "..."


def call_summary(name, inp):
    if name == "Bash":
        return short(inp.get("command", ""))
    for key in ("file_path", "pattern", "path", "query", "description"):
        if key in inp:
            return short(f"{key}={inp[key]}")
    return short(inp)


def result_text(content):
    if isinstance(content, list):
        return " ".join(c.get("text", "") for c in content if isinstance(c, dict))
    return content if isinstance(content, str) else ""


def digest(path):
    calls, order, errors = {}, [], []
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            content = rec.get("message", {}).get("content")
            if not isinstance(content, list):
                continue
            for item in content:
                if not isinstance(item, dict):
                    continue
                if item.get("type") == "tool_use":
                    if item.get("id") not in calls:
                        order.append(item.get("id"))
                    calls[item.get("id")] = (item.get("name", "?"), item.get("input") or {})
                elif item.get("type") == "tool_result" and item.get("is_error"):
                    name, inp = calls.get(item.get("tool_use_id"), ("?", {}))
                    errors.append((name, call_summary(name, inp), short(result_text(item.get("content")), 160)))
    counts = Counter(calls[i][0] for i in order if i in calls)

    # Longest run of consecutive search-like calls: a sign the agent could not find something.
    best, run, best_end = 0, 0, 0
    for idx, cid in enumerate(order):
        name, inp = calls.get(cid, ("?", {}))
        is_search = name in SEARCH_TOOLS or (name == "Bash" and SEARCH_BASH.match(inp.get("command", "")))
        run = run + 1 if is_search else 0
        if run > best:
            best, best_end = run, idx
    streak = [call_summary(*calls[c]) for c in order[best_end - best + 1 : best_end + 1]] if best else []

    repeated = Counter(call_summary(*calls[c]) for c in order if c in calls)
    repeated = [(k, n) for k, n in repeated.most_common() if n >= 3]
    return len(order), counts, errors, best, streak, repeated


def main():
    if len(sys.argv) != 4:
        print(__doc__.strip())
        return 2
    ws, project, task = sys.argv[1:]
    marker = f".agents/tasks/{project}/{task}/"
    paths = glob.glob(os.path.expanduser("~/.claude/projects/*/*/subagents/agent-*.jsonl"))
    found = []
    for path in paths:
        prompt = first_prompt(path)
        if marker in prompt:
            meta = {}
            try:
                with open(path[: -len(".jsonl")] + ".meta.json", encoding="utf-8") as fh:
                    meta = json.load(fh)
            except (OSError, ValueError):
                pass
            m = re.search(r"round (\d+)", prompt)
            found.append((os.path.getmtime(path), path, meta.get("agentType", "?"), m.group(1) if m else "-"))
    if not found:
        print(f"none: no subagent transcript names {marker} (manual mode runs, or logs cleaned up)")
        return 0
    for _, path, agent, rnd in sorted(found):
        total, counts, errors, streak_len, streak, repeated = digest(path)
        print(f"## {agent} round {rnd}")
        print(f"transcript: {path}")
        print(f"tool_calls: {total} ({', '.join(f'{k} {v}' for k, v in counts.most_common())})")
        print(f"failed_calls: {len(errors)}")
        for name, call, err in errors[:15]:
            print(f"  - {name}: {call}\n    -> {err}")
        if len(errors) > 15:
            print(f"  ... {len(errors) - 15} more")
        print(f"longest_search_streak: {streak_len}")
        if streak_len >= 8:
            for call in streak[:20]:
                print(f"  - {call}")
        if repeated:
            print("repeated_calls (3+):")
            for call, n in repeated[:10]:
                print(f"  - {n}x {call}")
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
