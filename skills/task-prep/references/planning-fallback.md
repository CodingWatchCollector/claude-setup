# Planning without oh-my-claudecode

Used when the OMC planning skill is not available in the session. All paths passed to subagents are absolute; subagents start in the workspace root, not in the repository.

## Standard mode

1. **Draft.** Write `plan.md` from the template using the context from Step 1. Name concrete files and public interfaces, not layers in general.
2. **Critic.** Start the `task-plan-reviewer` subagent with the Agent tool (general-purpose if it is missing). Give it only the paths to `plan.md` and the repository, the matched lesson entries and this brief:
   "Review this plan as a skeptical senior engineer. What is missing, ambiguous, or likely to break existing behavior? What would an implementer have to guess? Return a numbered list of issues with a proposed fix each, most severe first. Do not rewrite the plan and do not create any files."
3. **Revise** from the critique. Repeat the critic step at most twice.

## Strict mode

Before the critic, add an **architect** pass in its own `task-plan-reviewer` subagent with this brief:

"Check this plan for boundary and contract problems: API compatibility with existing frontend consumers, DTO and shared type changes, migration safety and rollback, auth implications, effects on other consumers of shared components. Return issues with proposed fixes. Do not rewrite the plan and do not create any files."

Revise, then run the critic. Also write the pre-mortem: imagine the change shipped and failed in production; describe 3 concrete ways it failed and how the plan or its tests would catch each one.
