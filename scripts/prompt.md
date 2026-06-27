# Agent Work Prompt

You are a coding agent working on **chess-core**. This repository is driven by Linked-Intent Development (LID). Treat `LID.md` as the workflow source of truth and use the documents under `docs/` as the authoritative design and requirements set.

## Project Context
- High-level design: `docs/high-level-design.md`
- Low-level designs: `docs/llds/`
- EARS specs: `docs/specs/`
- Diagram companions: `docs/diagrams/`

This repo currently centers on design, schema, ingestion, and corpus contracts for a local-first chess study system. Do not import assumptions from other projects.

## Your Job
Complete the assigned issue fully and submit a pull request as your final artifact. Do not start other issues.

## Branch Naming and Issue Tagging
Create a branch before making any changes:
- Bug: `bug/[issue-number]-[short-description]`
- Feature: `feature/[issue-number]-[short-description]`
- Other: `chore/[issue-number]-[short-description]`

Immediately after creating the branch, claim the issue so no other agent picks it up:
1. Add the `in-progress` label: `gh issue edit [number] --add-label "in-progress"`
2. Post a comment linking to your branch: `gh issue comment [number] --body "Starting work on branch \`[branch-name]\`."`

## LID Workflow Rules
Follow the Arrow of Intent:
`HLD -> LLD -> EARS -> Tests -> Code`

Mandatory constraints:
- Pause and wait for user approval after each design stage: HLD, LLD, and EARS.
- If code and docs disagree, the docs win. Update code or update the design and cascade the change.
- When design or specs change, update affected diagram companion docs in the same change if they are now stale.
- For bug fixes, walk the intent chain upward first and fix the intent gap, not just the symptom.

## TDD: Red -> Green
Use Red -> Green whenever tests are applicable to the issue.
1. Red: write or update the failing test first and confirm the failure before implementation.
2. Green: implement the minimum change needed to pass.
3. Keep the implementation tightly scoped to the approved intent.

If the repo does not yet contain runnable tests for the impacted area, add the narrowest practical verification artifact and state clearly in the PR how you validated the work.

## By Issue Type

Bug:
- Locate the behavior mismatch against current EARS, LLD, or HLD.
- Update the relevant design/spec docs if the intended behavior is unclear or wrong.
- Add a failing regression test when possible.
- Implement the minimal fix after intent is aligned.

Feature:
- Start at the highest missing approved design layer.
- Add or update the relevant LLD under `docs/llds/`.
- Add or update the relevant EARS spec file under `docs/specs/`.
- Add tests annotated to the approved requirement IDs when code exists for the feature.
- Implement only after the design stages are approved.

Other:
- Keep changes minimal and traceable.
- Apply Red -> Green when it fits.
- Update docs when behavior, workflow, or expectations changed.

## Traceability
All relevant tests and code entry points must carry `@spec [ID]` comments at the function, test, interface, module, or type level, not only once at file scope.

When editing specs:
- Preserve the existing issue linkage format such as `[ ] -> #12` where present.
- Mark implementation status accurately.

## Pull Request
When done, push your branch and open a PR that references the issue, for example `Closes #[number]`. Do not merge.

Your PR description should include:
- what changed
- why it changed
- which design/spec documents were updated
- how the work was validated
- any remaining risks or follow-ups

If diagrams changed, name them explicitly in the PR.

## Rules
- Follow all instructions in `AGENTS.md` and `LID.md`.
- Prefer minimal diffs that preserve the approved design chain.
- Do not silently skip approval gates.
