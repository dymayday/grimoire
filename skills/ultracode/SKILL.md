---
name: ultracode
description: >
  Use when the user invokes ultracode or /ultracode, or explicitly requests
  multiple specialist reviewers followed by independent verification and
  adjudication. Applies to code, documents, ideas, proposals, questions, and
  mixed evidence. Do not use for a single-reviewer /review or workflow authoring.
argument-hint: "[objective] [target]"
metadata:
  short-description: "Specialist review, verify, adjudicate"
---

# Ultracode

You orchestrate only. Do not answer the review task in this chat. Do not
`spawn_subagent`. Do not run the bundled `review` skill.

**REQUIRED BACKGROUND:** Read create-workflow for the workflow dialect, host
API, and `validate_only` procedure. Use `ultracode.rhai` beside this file as the
single workflow implementation.

## 1. Build a structured review brief

Strip a leading `ultracode` or `/ultracode` token. Resolve explicitly attached
or referenced artifacts without splitting paths on whitespace. Treat an idea,
proposal, question, or pasted text as a text artifact. Use the Git fallback
only when no target remains.

Pass one structured `brief` instead of independent target fields:

```json
{
  "objective": "<what to evaluate>",
  "target": "<inspectable path, complete supplied text, or concise mixed brief>",
  "artifact_kind": "<file|directory|diff|text|mixed|research>",
  "inspection": "<artifact-specific inspection contract>",
  "minimum_severity": "medium",
  "dedupe_threshold": 8,
  "artifacts": [
    {
      "ref": "proposal",
      "kind": "text",
      "locator": "<complete supplied text or stable local locator>",
      "role": "subject"
    }
  ]
}
```

### Artifact manifest

Add one manifest entry per supplied source. Use `ref` as its stable citation
ID: 1–24 letters, numbers, or hyphens, unique within the brief.

| Field | Meaning |
|---|---|
| `ref` | Stable ID used by reviewers, verifiers, and final evidence |
| `kind` | `file`, `directory`, `diff`, `text`, `url`, or another explicit kind |
| `locator` | Path, URL, complete supplied text, or other inspectable locator |
| `role` | Why the artifact is present: `subject`, `requirement`, `evidence`, etc. |

Use one entry for one target and multiple entries for mixed reviews. The
manifest is the allowed source set; agents cannot silently expand it.

### Artifact kinds and inspection

| Kind | Inspection contract |
|---|---|
| `file` / `directory` | Use `read_file` and `grep`; cite manifest refs plus line ranges or symbols. |
| `diff` | Read the diff and relevant changed sources. Findings must concern changed behavior or changed hunks. |
| `text` | Analyze supplied text directly; cite its manifest ref and exact statement, assumption, or section. |
| `mixed` | Inspect each relevant manifest artifact and cite all sources that support the claim. |
| `research` | Inspect the brief and perform delegated research. Register every new source before citing it; prefer primary sources. |

Do not give ideas or questions a file-only inspection contract.

### Severity threshold

Default `minimum_severity` to `medium` unless the user requests exhaustive or
nit-level review.

- `critical`: defeats the objective or creates unacceptable harm.
- `high`: likely material failure requiring correction.
- `medium`: important weakness with a viable workaround.
- `low`: limited impact; normally excluded before verification.

Materiality is separately calibrated:

- `objective-blocking`: prevents the stated objective.
- `material`: materially changes the decision or outcome.
- `significant`: needs action but does not decide the objective alone.
- `limited`: contained effect.

Confidence is evidence quality, not severity:

- `high`: direct specific evidence with no material contradiction.
- `medium`: specific evidence with a material uncertainty.
- `low`: plausible but weak or incomplete evidence.

`dedupe_threshold` controls when semantic consolidation runs. Default to `8`.
Below the threshold, findings proceed directly to verification.

### Git fallback

Run only when the parsed request is empty. Confirm a Git work tree and inspect
`git status --porcelain`. Create unique temporary files with `mktemp`; never
reuse fixed paths.

Dirty tree:

```bash
DIFF="$(mktemp "${TMPDIR:-/tmp}/ultracode-target.XXXXXX.diff")"
NAMES="$(mktemp "${TMPDIR:-/tmp}/ultracode-target.XXXXXX.names0")"
if git rev-parse --verify --quiet HEAD >/dev/null; then
    git -c core.quotepath=false diff --binary HEAD > "$DIFF"
else
    EMPTY_TREE="$(git hash-object -t tree /dev/null)"
    git -c core.quotepath=false diff --binary --cached "$EMPTY_TREE" > "$DIFF"
    git -c core.quotepath=false diff --binary >> "$DIFF"
fi
git -c core.quotepath=false diff --name-only -z HEAD 2>/dev/null > "$NAMES" ||
git diff --cached --name-only -z > "$NAMES"
git ls-files --others --exclude-standard -z | while IFS= read -r -d '' f; do
    git -c core.quotepath=false diff --binary --no-index -- /dev/null "$f" >> "$DIFF" || true
    printf '%s\0' "$f" >> "$NAMES"
done
if [ ! -s "$DIFF" ]; then echo "empty diff"; exit 1; fi
```

For a clean tree, prefer `origin/main`, then `origin/master`. Ask for a base if
neither exists or `HEAD` is missing. Write binary diff and NUL-delimited names
to unique temporary files. Abort on an empty diff.

For either path:

- Create a `diff` artifact for `DIFF` and manifest entries for changed sources.
- Read `NAMES` as NUL-delimited data.
- Reject local locators containing `.` or `..` path components.
- A deleted path can use the diff and an existing ancestor directory artifact.
- Remove temporary files after completion, including failed launches.

## 2. Define lens contracts

Choose **3–5** genuine, non-overlapping dimensions after inspecting the brief.
Each dimension is:

```json
{
  "id": "D1",
  "name": "failure modes",
  "justification": "The proposal changes an operational cutover.",
  "focus": "Material ways the cutover can fail and their effects.",
  "excludes": [
    "Whether assumptions are supported",
    "Whether the proposal contradicts itself"
  ],
  "scope_refs": ["proposal", "runbook"],
  "reviewer_count": 1,
  "redundancy_reason": ""
}
```

- IDs are unique, stable, and safe: 1–24 letters, numbers, or hyphens.
- `justification` says why the lens applies to the inspected artifact.
- `focus` defines what the reviewer owns.
- `excludes` defines neighboring concerns it must not report.
- `scope_refs` contains only manifest refs.
- `reviewer_count` is `1` normally and `2` only for selected high-risk lenses.
- A duplicated lens requires a concrete `redundancy_reason`.

Choose lenses by artifact:

- **Code/diff:** include correctness. Add security, tests, UI, performance, or
  compatibility only when the artifacts justify them.
- **Skill/document:** use procedure gaps, contradictions, failure accounting,
  prompt quality, triggers, or other present concerns.
- **Idea/proposal:** use assumptions, coherence, feasibility, failure modes,
  trade-offs, evidence, or falsifiability as relevant.
- **Question:** split its actual concerns without padding.

### Adaptive reviewer redundancy

Use two reviewers only where independent discovery materially improves safety:
security boundaries, cryptography, permissions, destructive migrations,
high-stakes architecture, irreversible operations, or another explicit risk.
Do not duplicate every lens. Both reviewers keep distinct stable IDs such as
`D2-R1` and `D2-R2`; their findings remain separately attributable.

## 3. Review quality gate

Before Verify, the workflow enforces:

- Every expected reviewer has a visible success or failure record.
- Every successful reviewer provides a concrete inspection account.
- Findings have stable IDs derived from dimension, reviewer, and position:
  `D2-R1-F3`.
- Each finding includes title, precise claim, inspected evidence, impact,
  calibrated materiality level plus explanation, severity, confidence,
  lens-fit explanation, and exact sources.
- Deterministic checks reject malformed, below-threshold, or unauthorized-source
  findings. A separate read-only quality gate classifies each remaining finding
  against the lens focus and exclusions and checks severity, materiality, and
  confidence calibration before Verify. Gate failures and
  rejections enter `qualityRejected` with the original entry and reason.
- `coverage` records expected reviewers, successful reviewers, accepted
  findings, and complete/partial/failed status for every dimension.
- Successful zero-finding reviews retain their inspection accounts.

### Source registry

The initial `sourceRegistry` is the artifact manifest. For `research`, agents
may add sources through `discoveredSources` only when each entry has:

```json
{
  "ref": "official-spec",
  "kind": "url",
  "locator": "https://example.org/spec",
  "sourceType": "primary",
  "reason": "Defines the requirement under review",
  "inspected": true
}
```

Findings and verifier evidence may cite supplied sources or registered research
sources. Other artifact kinds cannot add sources. Invalid source registrations
enter `sourceErrors`.

### Conditional deduplication

At `dedupe_threshold`, run one read-only consolidation agent before Verify.
It receives findings only; it cannot inspect artifacts or judge truth. It
partitions every finding exactly once into semantic claim groups and returns
only member IDs. The workflow preserves member provenance and derives each
consolidated ID, title, and claim from the earliest original member. Invalid or
incomplete grouping fails open to separate verification and enters
`dedupe.errors`.

Below the threshold, skip consolidation to avoid an agent call when duplication
is unlikely.

## 4. Verify and adjudicate

Verification is **one verifier per distinct claim**, not per file. Several
claims may use the same source, and one claim may cite multiple sources.

Verifier labels are bounded and stable:

```text
verify:<claim-id>:<short-normalized-title>
```

Keep full lens names and titles in the structured packet. Give the verifier the
brief, source registry, canonical claim, all member findings, lens contracts,
calibration, and source refs. It independently tries to falsify the claim and
returns auditable evidence. Missing, malformed, or unauthorized evidence enters
`noVerdict` with the attempted output.

The judge sees only Review+Verify cases. It does not inspect artifacts or add
sources. Unknown IDs, duplicate IDs, empty rationales, malformed output, and
omissions fail closed into `judgeErrors` or `unjudged`.

## 5. Launch

Read `ultracode.rhai`, then call `workflow` with:

```json
{
  "brief": { "...": "the structured brief from section 1" },
  "dimensions": [
    { "...": "3-5 lens contracts from section 2" }
  ]
}
```

1. Before each workflow call, compute the worst-case agent budget:
   `reviewers + 2*reviewers*8 + 2`, plus `1` when
   `reviewers*8 >= dedupe_threshold`. `reviewers` is the sum of all
   `reviewer_count` values. Pass this as `agent_budget`; it covers reviewers,
   one quality gate and one verifier per maximum finding, optional dedupe, and
   the judge. Live concurrency remains capped at eight.
2. Smoke-check with `validate_only: true`, representative args, and that budget.
3. Fix only validation failures. The canned result is not a live review.
4. Launch the same script without `validate_only` and with identical args and budget.
5. Report only the session-unique display name while it runs. Do not poll.
6. On completion, report all buckets: `kept`, `dropped`, `unjudged`,
   `noVerdict`, `inspections`, `coverage`, `qualityRejected`,
   `failedReviewers`, `sourceRegistry`, `sourceErrors`, `dedupe`, and
   `judgeErrors`.
7. Clean up generated temporary files on every terminal outcome.

Do not save a workflow projection unless the user asks.

## 6. Workflow guarantees

`ultracode.rhai` owns these guarantees:

- Structured artifact manifest and source registry.
- Stable dimension, reviewer, finding, and consolidated-claim IDs.
- Lens justification, focus, exclusions, and explicit scope refs.
- Severity, confidence, and materiality calibration before Verify.
- Complete Review coverage and quality-gate accounting.
- Conditional semantic deduplication with provenance preservation.
- Adaptive duplicate reviewers only for marked high-risk lenses.
- Claim-centered verification with bounded meaningful labels.
- Registered and auditable evidence through Review and Verify.
- Complete evidence packets in final results.
- Fail-closed verification and adjudication accounting.
- Parallel panels in batches of at most eight agents.
