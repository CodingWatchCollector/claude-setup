---
name: task-run
description: Execute a task prepared and approved by task-prep in a multi-repository workspace. Runs the optional acceptance tester, the implementer and the reviewer as fresh subagents from the context files in <workspace>/.agents/tasks/<project>/<TASK-ID>/, loops fix and review rounds up to a limit, checks every handoff with a deterministic gate script, and stops for the user on blockers, disputed findings or the round limit. Use when the user runs /task-run or asks to execute an approved task. Orchestrates only, never implements or reviews itself.
---

# task-run

Execution stage of a three-step workflow:

1. **task-prep**: plan, validate, approve, write context files.
2. **task-run** (this skill): acceptance tester (optional), implementer and reviewer rounds.
3. **task-retro**: review findings -> lessons, contract docs, metrics.

## Rules

- You are the orchestrator. Never edit code, write tests, fix findings or review code yourself, even when it looks faster. Your job: start the right agent with the right brief, run the gate, decide the next step.
- Every agent is a **fresh** subagent of a named type, started with the Agent tool: `task-acceptance-tester`, `task-implementer`, `task-reviewer`. Never substitute a general-purpose subagent: subagents do not inherit skills from this session, and only the named types preload `tdd` and `code-review` and carry the intended model. Never continue or reuse a previous subagent: a clean context is the point of the design, and a reviewer must never see the implementer's reasoning.
- Keep your own context lean. Do not read diffs or source files. Read gate output, the Implementer report, the Blockers section and findings headers.
- Change the status table only through `gate.sh set`, so the format stays parseable. Subagents write their own reports.
- You may write only: the Log and Blockers sections of `status.md` (including `rules confirmed` lines), `decision:` and `nonblocking decision` lines in `findings.md`, and review rounds through `gate record-findings`. Nothing inside the repository.
- Never commit, push or merge.
- Plain ASCII punctuation in everything you write.

## Input

`/task-run <project> <TASK-ID> [--max-rounds N] [--manual]`

Default `--max-rounds` is 3. `--manual`: see the end of this file.

## Gate

`bash <this skill's folder>/scripts/gate.sh <project> <TASK-ID> <command> [arg]`, run from the workspace root. Pass the round limit as `MAX_ROUNDS=<N>` in the environment of every `next` call.

Shell rules (the user's shell may be zsh, which does not word-split variables):

- Write every gate call in full, with the absolute path to `gate.sh`. Never store a command or part of one in a shell variable and run it as `$VAR`.
- One gate command per Bash call, or chain full commands with `&&`. Check each exit code before acting on the next.

Exit codes: `0` pass, `1` fail, `3` needs the user. Always show FAIL and USER lines to the user verbatim. In manual mode, run `start` as `MANUAL=1 gate.sh ... start`.

`<TASK_DIR>` below is `<workspace>/.agents/tasks/<project>/<TASK-ID>` as an absolute path.

## Step 0 - Start

1. Run `gate start`. On FAIL, show the output and stop: the task is not ready (task-prep did not finish) or an agent file is missing. The OK lines show each agent's model and skills: include them in your first message to the user.
2. Run `gate next` and tell the user where execution starts (for example "implementation round 1", or "resuming at review round 2"). This is how interrupted runs resume: always trust `gate next`, not your memory of the conversation.
3. Loop: act on `gate next` until it says `done`, `limit` or `needs-user`.

After every step, append one line to the Log section of `status.md`: date, step, round, gate result.

## next: tests

1. `gate set run:acceptance-tests in-progress`
2. Start a `task-acceptance-tester` subagent with exactly this prompt:
   > You are the acceptance tester for task <project>/<TASK-ID>. Your whole brief is <TASK_DIR>/context-tests.md. Read it first and follow it exactly, including its "When done" section.
3. `gate after-tests`. Exit 0: continue. Exit 3: see Blockers. Exit 1: see Retry.

## next: impl <n>

1. `gate set run:implementation in-progress`
2. Start a `task-implementer` subagent with exactly this prompt:
   > You are the implementer for task <project>/<TASK-ID>, implementation round <n>. Your whole brief is <TASK_DIR>/context-impl.md. Read it first and follow it exactly, including its "When done" section, which applies to every round. From round 2 on, <TASK_DIR>/findings.md holds the review findings you must handle.

   When this round follows a `nonblocking decision ... fix`, add to the prompt: "This round fixes the non-blocking findings of review round <n-1> that are still open: handle every one of them."
3. `gate after-impl <n>`. Exit 0: continue. Exit 3: see Blockers, Disputes or Rules decided, depending on the USER line. Exit 1: see Retry.

## next: review <n>

1. `gate set run:review in-progress`, then `gate snapshot`.
2. Start a `task-reviewer` subagent with exactly this prompt:
   > You are the reviewer for task <project>/<TASK-ID>, review round <n>. Your whole brief is <TASK_DIR>/context-review.md. Read it first and follow it exactly. You did not write this code and you must not change it. Do not write any file: return the review round as your final message, in the Output format of your brief, with nothing before or after it.
3. Save the returned text verbatim, without editing a single character, through a quoted heredoc:
   ```
   bash <gate path> <project> <TASK-ID> record-findings <n> << 'FINDINGS_EOF'
   <the reviewer's final message>
   FINDINGS_EOF
   ```
   If it fails (missing header, wrong round), that is a reviewer failure: see Retry.
4. `gate after-review <n>`. It prints the verdict and writes `rounds: <n>` into the Notes cell of the `run:review` row. Exit 1: see Retry.
5. Tell the user in two or three lines: verdict, number of open blocking findings, their titles. Then continue the loop.

## next: done

1. `gate set run:review done`
2. Run `gate summary` and show it.
3. Tell the user: review the diff yourself, commit when satisfied, then run `/task-retro <project> <TASK-ID>` if available. `findings.md` is its input, do not delete it.
4. Stop.

## next: limit

The round limit is reached without APPROVE. Stop and show: open blocking findings with one line each, and how many findings have `source: plan`. If plan-sourced findings dominate, recommend going back to task-prep for this task rather than raising the limit: more rounds will not fix a wrong plan. The user may rerun with a higher `--max-rounds`.

## Retry (gate exit 1)

Start one more **fresh** subagent of the same named type, with the same prompt plus:

> A previous attempt in this round failed these automatic checks:
> <FAIL lines from the gate>
> Fix only what they point at, then finish with the "When done" section of your brief.

For the reviewer, replace the last sentence with: "Then return the complete review round as your final message, in the Output format of your brief." Its output goes through `record-findings` again; if round <n> was already recorded but failed `after-review`, tell the user instead of retrying, since the recorded round would need a manual fix.

Run the same gate command again. A second failure in the same round: stop, show the gate output, and ask the user how to proceed. Do not try a third time.

## Blockers (needs-user: tests-blocked or impl-blocked)

1. Show the open question from the Blockers section of `status.md`.
2. Wait for the user's answer. Append it under that blocker as `decision (<date>): <answer>`.
3. `gate set` the step back to `in-progress` and rerun the same step and round with a fresh subagent. The context files tell agents to read resolved blockers.

## Rules decided (needs-user: rules)

The implementer chose a business rule that neither the plan nor a recorded decision covers. This is the moment to catch it: before a reviewer rates it and before it spreads into tests and docs. Show each rule from the `rules decided` list of the Implementer report, with its location and reason. For each, the user decides:

- **Confirm:** it becomes a decision.
- **Reject:** the user states the rule to apply instead.

Then:

1. Append under Blockers in `status.md`: one `decision (<date>): R-<k> <confirmed | rejected: rule to apply>` line per rule.
2. If all were confirmed, also append `rules confirmed (round <n>): R-1, R-2, ...` and continue the loop: `gate next` moves on to the review.
3. If any was rejected, `gate set run:implementation in-progress` and rerun the same implementation round with a fresh `task-implementer`. The brief tells it to read the decisions under Blockers; rules already decided there no longer count as `rules decided`.

## Non-blocking findings after APPROVE (needs-user: nonblocking)

The reviewer approved, but findings of that round are still open. Show them with one line each. The user decides:

- **Fix now:** append `nonblocking decision (round <n>): fix` to `findings.md` and continue the loop. `gate next` starts implementation round n+1, a normal gated round followed by a re-review. Never fix them any other way: an ad hoc fix outside the gate leaves the Implementer report stale and the fixes unreviewed.
- **Leave them:** append `nonblocking decision (round <n>): leave` and continue: `gate next` returns `done`, and task-retro will pick them up as leftovers.

The fix round counts against `--max-rounds`. If the limit is already reached, `gate next` returns `limit`: say so and let the user rerun with a higher limit or leave them.

## Disputes (needs-user: disputed)

The implementer disagreed with a blocking finding. Show the finding and the implementer's `reason:`. Ask the user to decide:

- **Accept the dispute:** set the finding to `status: waived` and add `decision: <user's words>`. Then continue the loop: `gate next` will move to review.
- **Keep the finding:** set it to `status: open`, add `decision: <user's words>`, `gate set run:implementation in-progress`, and rerun the same implementation round with a fresh subagent.

## Manual mode (--manual)

Same loop and same gates, but instead of starting subagents, show the user the exact prompt for the current step and ask them to run it in a fresh session (`/clear` first, or another terminal), then to tell you when it finished. Run the gate afterwards as usual. Use it when the agent files are missing, when a subagent fails to start (for example a model availability error), or to watch a step closely.

With each prompt, tell the user which model to select in that session with `/model`, taken from the agent files: sonnet for the tester and implementer, opus for the reviewer, unless the files say otherwise. In a fresh session the brief tells the agent to invoke its skill if it is not preloaded, so skills still work.
