# Default spec contract

The output shape concretize writes against when the repository has no spec template of its own. A repo's own template overrides this file entirely. The spine converges with the formats worth referring to — the opening is an RFC's Motivation, `## Settled` its Rationale and alternatives written inline at the decision, `## Open questions` its Unresolved questions, `## Not in scope` a KEP's Non-Goals, `## Plan` spec-kit's tasks, `## Definition of done` a KEP's graduation criteria.

**The opening — one to three paragraphs, no heading.** What is missing today, why it matters now, and what it unblocks, written for a reader with no surrounding context — this is the only place they learn why the work exists at all. Name what it depends on and what those dependencies leave undone.

## Scope

What this builds, as a short list or a few paragraphs — concrete enough that a reader can tell whether a given change belongs to this work or to a neighbour.

## Settled: \<the decision, stated as a claim\>

One section per load-bearing decision, headed by the decision itself rather than the topic — `## Settled: templates are compiled in`, not `## Templates`. Each records what was decided, why, what the alternative was and what it lost on, and what the choice costs — a cost written here is a cost paid; a cost discovered during implementation is a surprise. Repeat the heading per decision. A spec with none is either trivial or has not been concretized.

## Open questions

Only decisions genuinely still open, each with who or what settles it and when. A question the implementation cannot avoid does not belong here — settle it, or state that the implementer chooses and on what grounds. A question that blocks nothing here but blocks later work belongs here, named, with what it blocks. Write `None.` when there are none; an absent section reads as an unanswered one.

## Not in scope

What this deliberately does not do, and where it goes instead — follow-up work, a later phase, or nowhere. Adjacent work a reader would reasonably expect here is the point; listing the obviously unrelated is noise.

## Plan

The implementation as ordered checkboxes, written for someone with no context beyond this spec: files named by path; where one task produces something a later task consumes, the actual name; tests as their own steps, not an afterthought. No placeholders — "add error handling", "write tests for the above", and "TBD" are plan failures, not shorthand. A checkbox that would attract its own discussion, or that outside work would need to wait on, is its own draft rather than a task.

## Definition of done

Checkable criteria, where every criterion names the thing that fails when it is not met — a test, a command, an assertion, a measured number. "Works correctly" is not a criterion. A criterion that can only be confirmed by reading the diff is a review note: move it into `## Plan` or drop it.

**For an experiment** — work whose deliverable is a result rather than code — fix before the run: the one pre-registered question, the arms compared, the primary metric, what counts as a null result, and how many runs it takes to see the effect claimed. Metrics chosen after a result are not metrics.

**Ceremony scales with the work; the sections do not change.** A spike needs the opening, `## Scope`, and a `## Definition of done` that says what would settle its question — near-empty `## Settled` and `## Plan` are then correct. Everything else fills the whole shape, and the ratchet is one-way: complexity found mid-concretization upgrades the spec, and nothing downgrades it.
