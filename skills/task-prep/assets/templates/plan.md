# <PROJECT>/<TASK-ID>: <title>

project: <PROJECT>
repo: <REPO>
mode: standard | strict
source: <ticket link | pasted text>
approved: no
approved_on:

## Goal

<!-- One or two sentences: what changes for the user or the system, and why. -->

## Scope

## Out of scope

## Affected areas

| Layer | Files / modules (relative to repo) | Change |
|---|---|---|

## API contract

<!-- "none" if no endpoint, DTO, shared type or Swagger schema changes. -->

- Endpoint:
- Request:
- Response and status codes:
- Error format:
- Frontend consumers:
- Backward compatibility:

## Acceptance criteria

<!-- AC-1: Given ... When ... Then ... -->

## Test seams and traceability

| AC | Seam (public interface) | Test level | Test file |
|---|---|---|---|

<!-- Mutation or scratch-copy recipes run outside the repo root: call tools by absolute path (<repo>/node_modules/.bin/<tool>), not pnpm exec / npx, and abort when the baseline run errors. -->

## Regression set

<!-- Existing spec files that cover touched modules and must stay green. -->

## Lessons applied

| Lesson | How the plan addresses it |
|---|---|

## Risks

<!-- Strict mode: pre-mortem, 3 failure scenarios and how each is caught. -->

## Assumptions

## Open questions

<!-- - [blocking] ...   - [non-blocking] ... -->

## Definition of done

<!-- Real commands run inside the repository, for example: cd <REPO> && npm run test -- <paths> -->

## Acceptance tester

needed: no
reason:
