---
name: task-prep
description: Prepare a development task for agent execution in a multi-repository workspace. Resolves the target repository or worktree, checks prerequisites, gathers code context and past lessons for that project, produces a plan with testable acceptance criteria and test seams, validates it with a separate subagent, gets explicit human approval, then writes self-contained context files for the implementer, the reviewer and an optional acceptance tester under <workspace>/.agents/tasks/<project>/<TASK-ID>/. Use when the user runs /task-prep or asks to plan or prepare a task for the implement-and-review workflow. Plans only, never writes code, tests or any file inside a repository.
---

# task-prep

Planning stage of a three-step workflow:

1. **task-prep** (this skill): plan, validate, approve, write context files.
2. **task-run**: implementer (+ optional acceptance tester) and reviewer, in a fresh session.
3. **task-retro**: review findings -> lessons, contract docs, metrics.

Why everything goes to files: execution agents start with a clean context and no access to this conversation. Whatever they need must be on disk. Files also survive compaction, crashes and new sessions.

## Workspace layout

The Claude session starts in a workspace directory that contains several git repositories and their worktrees. The workspace is not a repository itself.

```
<workspace>/
  .agents/
    lessons/README.md
    lessons/_shared/*.md          optional, lessons valid for every project
    lessons/<project>/*.md
    tasks/<project>/<TASK-ID>/
  <project>/                      main checkouts
  <worktree dirs>                 anywhere, often siblings of the main checkout
```

**Workspace root** is the nearest directory, going up from the current working directory, that contains `.agents/`. If none exists, use the directory the session started in, after confirming with the user, and create `.agents/lessons/` and `.agents/tasks/` there.

**Project name** is the directory name of the main checkout, derived from git, so a worktree maps to the same project and lessons as its main repository. `scripts/resolve-repo.sh` does this.

## Hard rules

- Never create, modify or delete any file inside a repository or worktree. No CLAUDE.md, `.claude/`, `.agents/`, `.omc/`, notes or plans there. Repositories receive only code changes, and only from task-run. All files this skill writes are under `<workspace>/.agents/`.
- Run every git and package-manager command against the target repository explicitly (`git -C <repo>`, or `cd <repo> && ...`), never from the workspace root.
- Never generate context files without explicit user approval of the final plan.
- Update `status.md` after every step so a later session can resume.
- Never hand off to an execution mode of another plugin (OMC team, ralph, autopilot, ultrawork). Execution belongs to task-run.
- Artifacts use plain ASCII punctuation: a hyphen instead of long dashes, straight quotes and apostrophes.
- Write artifacts in the language of the task description, unless the repository's AGENTS.md sets a project language. Keep template headings and field keys unchanged, scripts and other skills parse them.

## Input

- `/task-prep <repo> <TASK-ID> <task text or ticket content> [--strict | --light]`
- `/task-prep --check [<repo>]`: run Step 0 only, print the report, stop.

`<repo>` is a project name or a path to a main checkout or worktree. If it is a name, find the main checkout in the workspace, list its worktrees with `git -C <main> worktree list`, and ask which one to use unless there is only one. If `<repo>` or the ID is missing, ask for it.

If the task dir already exists, read its `status.md` and resume from the first step that is not `done`. Tell the user which step you resume from.

## Step 0 - Preflight

1. Find the workspace root (see above). Create `.agents/lessons/` and `.agents/tasks/` if missing, and copy `references/lessons-format.md` to `.agents/lessons/README.md` if missing.
2. Run `bash <this skill's folder>/scripts/resolve-repo.sh <repo path>`. It prints project, repo, main_repo, worktree, branch, head, uncommitted count and tool files found inside the repository.
3. Uncommitted changes make `base_commit` and the later review diff unreliable: warn and ask whether to continue.
4. Tool files inside the repository (`.claude/`, `.agents/`, `.omc/`, `CLAUDE.md` that git does not track): warn, they break the "repositories stay clean" rule. Remember which ones already existed, so later steps can tell what they created.
5. Skills available in this session (look at your list of available skills; names may carry a plugin prefix):
   - OMC planning skill (`oh-my-claudecode:omc-plan`, `oh-my-claudecode:plan` or `ralplan`): optional. Without it, planning uses `references/planning-fallback.md`.
   - `tdd` and `code-review`: required by the execution stage, since the context files tell agents to invoke them. If either is missing, warn clearly.
6. Lessons: number of entries in `.agents/lessons/_shared/` and `.agents/lessons/<project>/`.
7. Agents in `<workspace>/.claude/agents/` or, if not there, `~/.claude/agents/` (a workspace copy takes precedence): `task-plan-reviewer` (used here), and `task-implementer`, `task-reviewer`, `task-acceptance-tester` (used by task-run). Report each as found with its `model:` and `skills:` lines, or missing. A missing `task-plan-reviewer` is not blocking: fall back to a general-purpose subagent. Missing execution agents: warn that task-run will need `--manual`. If an agent's `skills:` line names a skill that item 5 did not find, warn: that agent would start without its skill.

Report format:

```
task-prep preflight
- workspace: <path>
- project: <name>   repo: <path>   worktree: <yes | no>
- git: <branch>, <clean | N uncommitted changes>
- tool files in repo: <none | list>
- OMC planning: <skill name | not found -> fallback planning>
- tdd: <found as NAME | MISSING>
- code-review: <found as NAME | MISSING>
- lessons: <project>: <N entries | none>, _shared: <N entries | none>
- agents: <name (model) for each found | missing: names>
```

With `--check`, stop after the report. Without `<repo>`, skip the repository lines.

## Step 1 - Gather context

1. Create `.agents/tasks/<project>/<TASK-ID>/` and `status.md` from `assets/templates/status.md`. Fill project, repo (absolute path), main_repo, branch and `base_commit` (`git -C <repo> rev-parse HEAD`).
2. Read the repository's AGENTS.md (team conventions) and CLAUDE.md if tracked, plus CONTEXT.md and ADRs (`docs/adr/` or similar) if they exist. Their vocabulary and decisions constrain the plan.
3. Explore the code the task touches. For anything broader than a few files, use the built-in Explore subagent, give it the absolute repository path, and keep only its summary: relevant files, public interfaces, existing spec files for those areas.
4. Match lessons from `.agents/lessons/_shared/` and `.agents/lessons/<project>/`. Read the `trigger` line of every entry and select those that overlap the task text or the files likely to change. Prefer recall over precision: a false positive costs one row in the plan, a miss repeats a known bug. Refer to lessons as `<folder>/L-<n>` (for example `_shared/L-003`, `billing-api/L-012`). Record selected IDs in `status.md`.

## Step 2 - Choose the mode

Use `strict` if the user passed `--strict` or the task touches any of:

- API contract: endpoints, DTOs, shared types, Swagger schemas, response or error formats
- Database: entities, migrations, schema changes, data backfills
- Auth: guards, interceptors, permissions, tokens
- Shared component library code consumed by more than one app
- Destructive or irreversible operations on data

Otherwise use `standard`. `--light` forces standard even if a trigger matches; note the override in `status.md`.

## Step 3 - Produce the plan

Target format is `assets/templates/plan.md`.

**OMC planning skill available:** invoke it from the workspace root, adding `--consensus` in strict mode. Never pass `--interactive`: in interactive mode OMC hands the approved plan to its own executors. Tell it the absolute repository path and that it must not write anything inside the repository. Give it the task text, the matched lessons, and this requirement: acceptance criteria in Given/When/Then, and for each criterion the public interface through which it will be tested. If OMC offers to start execution, decline.

When it finishes, find its plan file: newest file under `<workspace>/.omc/` (usually `.omc/plans/`), otherwise under `<repo>/.omc/`. Map it into `plan.md`. If OMC created `.omc/` inside the repository and it did not exist at Step 0, tell the user and propose removing it; do not delete without confirmation. Fill the sections OMC does not produce (seams table, lessons applied, regression set, API contract, definition of done) yourself.

**Otherwise:** follow `references/planning-fallback.md`.

Definition of done must contain real commands that run inside the repository (`cd <repo> && npm run ...`). Take them from the repository's package.json scripts and confirm each script exists. Every command you put into a brief must be read-only for the repository, git index included: the reviewer runs them and the repository is compared before and after the review. For greps over added lines, use the form given in the review template's "Read-only commands" section.

## Step 4 - Validate

Start the `task-plan-reviewer` subagent with the Agent tool (general-purpose if it is missing). Pass it only the absolute paths to `plan.md`, the repository and the matched lesson files, plus the full text of `references/validation-checklist.md`. It must not see this conversation: the author of a plan is bad at seeing its gaps.

On FAIL: revise the plan (small fixes directly, structural ones through the Step 3 route again) and re-validate. Maximum 3 rounds, then stop and show the user the remaining issues. After each validation round, set the Notes cell of the `prep:validation` row in `status.md` to `rounds: <n>`.

## Step 5 - Human approval

Show the user a short summary, not the whole file:

- project, repository path, branch
- goal, scope, out of scope
- acceptance criteria (one line each)
- seams and test levels
- lessons applied
- API contract changes, if any
- mode, and whether an acceptance tester will run, with the reason
- assumptions and open questions, blocking ones first
- preflight warnings that still apply (missing skills, dirty tree, tool files in repo)

Blocking questions must be answered before approval. Apply the user's edits to `plan.md` and re-run validation if the edits change criteria, scope or contract. Proceed only on an explicit approval. Set `approved: yes` and the date in `plan.md` and mark the step in `status.md`.

## Step 6 - Write context files

From `assets/templates/`:

- `context-impl.md`: always
- `context-review.md`: always
- `context-tests.md`: only if the plan says the acceptance tester is needed

Replace every placeholder. `<REPO>`, `<MAIN_REPO>` and `<TASK_DIR>` get absolute paths: subagents start in the workspace root, so the repository path in each file is what keeps them in the right place. `<TDD_SKILL>` and `<REVIEW_SKILL>` get the exact skill names found in Step 0. If several skills share a short name, use the fully qualified one (for example `mattpocock-skills:code-review`) and tell the user which one you picked.

Each file must be self-contained. The agent reading it has never seen this conversation. Copy the needed plan sections into it instead of writing "see above" or "as discussed". Slice deliberately:

- **tests**: goal, acceptance criteria, API contract, test conventions and existing test infrastructure. No implementation plan, otherwise tests start mirroring the implementation instead of checking behavior.
- **impl**: everything in the plan relevant to building it, including seams in implementation order, full lesson entries, rules for tests, definition of done.
- **review**: acceptance criteria, scope, contract, full lesson entries as a checklist, regression set, `base_commit`, findings format.

Then run `bash <this skill's folder>/scripts/check-task.sh <project> <TASK-ID>` from the workspace root. Fix every FAIL and run it again. Report WARN lines to the user.

## Step 7 - Hand off

Mark prep steps `done` in `status.md`. Tell the user to start a fresh session in the workspace (`/clear` or a new terminal) and run `/task-run <project> <TASK-ID>`. If task-run is not available in this session, say so and list the generated files instead. Stop here.
