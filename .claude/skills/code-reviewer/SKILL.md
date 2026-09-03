---
name: code-reviewer
description: |
  Orchestrate comprehensive code review and refactoring workflows for tanuki
  using the shared review workflow guide and delegated skills.
argument-hint: |
  [mode] [path]

  Mode (required):
    local                    Review current branch vs origin/main
    pr:<id>                  Review GitHub PR (e.g., pr:123)
    refactor:all             Refactor all changed files
    refactor:file:<path>     Refactor a single file
    refactor:dir:<path>      Refactor a directory

  Path (optional):
    - If omitted: uses the system temp directory (default)
    - Positional phrasing: Use code-reviewer for a local review and save it to /tmp/my-review.md
    - Keyword phrasing: Use code-reviewer for a local review and write it to /tmp/my-review.md

  Supported keywords: to, save to, output to, write to, at
invocation-syntax: |
  claude: /code-reviewer local /tmp/review.md
---

# Code Reviewer

## §0 When to Use This Skill
**Use this skill when**:
- The user requests a full local branch review or a pull request (PR) review.
- The user requests multi-file refactoring with a report.

**Do NOT use this skill when**:
- The request is unrelated to review/refactor workflows.
- The user wants a single-file audit or fix (use `code-quality`).
- The user wants to post a comment without a review (use `vcs-workflow-manager`).

## §0.5 Anti-Patterns (What NOT to Do)
❌ **WRONG: Manual file-by-file review without SKILL**

**Scenario**: User says "review my branch"
```
git diff origin/main...HEAD
# Read the diff and write an opinion
```

**Problems**:
1. No automated gate first — `gofmt`, `go vet`, `go test -race` never run, so a
   broken branch gets a stylistic review instead of "this does not compile".
2. No standardized report structure or verdict rule.
3. Findings without `file:line`, which the author cannot act on.
4. Uneven coverage: the first files get scrutiny, the last get skimmed.
5. A diff cannot be compiled — reviewing the patch text misses real breakage.

✅ **CORRECT: Use this SKILL**
```
Use code-reviewer for a local review.
```

**What this provides**:
1. Decision-matrix routing (review-workflow §2).
2. An automated gate whose results lead the report.
3. Per-file audits delegated to `code-quality` with a fixed output contract.
4. Cross-file synthesis, a deduplicated finding list, and a rule-based verdict.

## §0.6 Why This Matters
**Safety implications**:

| Aspect | Manual Review | This SKILL |
| --- | --- | --- |
| Automated gate | ❌ Optional | ✅ Runs first, leads the report |
| Scope control | ❌ Ad-hoc | ✅ Guided by the diff |
| Report structure | ❌ Inconsistent | ✅ Standardized + verdict rules |
| Finding traceability | ❌ Vague | ✅ `file:line` required |
| Refactor safety | ❌ No baseline | ✅ Baseline + rollback SHA + per-file verification |
| Posting authority | ❌ Unbounded | ✅ COMMENT only; APPROVE/merge refused |

**Real-world consequences**:
- 🚨 Missed regressions from uneven coverage.
- 🚨 A refactor validated against an already-red baseline proves nothing.
- 🚨 An agent approving its own PR bypasses human review entirely.

## §0.7 Path Conventions (read first)
See `@.ai/contexts/path-conventions.md`.

## §1 Routing & Classification
**User intent → Guide section mapping**:

| User Intent | Interpret As | Jump to Guide Section |
| --- | --- | --- |
| "Review my branch/changes" | Local review | `@.ai/contexts/review-workflow.md` → **§3.1** |
| "Review PR #<id>" | PR review | `@.ai/contexts/review-workflow.md` → **§3.2** |
| "Refactor the changed files" | Refactor workflow | `@.ai/contexts/review-workflow.md` → **§3.3** |
| "Just generate the report" | Report generation | `@.ai/contexts/review-workflow.md` → **§3.6** |
| "Post the review to the PR" | Review posting | `@.ai/contexts/review-workflow.md` → **§3.7** |

## §1.5 Quick Decision Tree (for AI routing)
1. IF mode is `local` → load §3.1.
2. ELSE IF mode is `pr:<id>` → load §3.2.
3. ELSE IF mode starts with `refactor:` → load §3.3 (+ §4 confirmation gates).
4. ELSE IF the request is "post it" after a report exists → load §3.7.
5. ELSE → ask for a valid mode (§9.1).

## §2 Load Strategy
**Authoritative references**:
- Primary guide → `@.ai/contexts/review-workflow.md`
- Audit criteria → `@.ai/contexts/code-style-guide.md` §10
- Posting mechanics → `@.ai/contexts/vcs-workflow-guide.md` §3.3

**On-demand load map**:
- Local review → §3.1 + §7
- PR review → §3.2 + §7
- Refactor → §3.3 + §4
- Report output → §3.6
- Posting → §3.7 + VCS §3.3.1/§3.3.2

## §3 Execution Protocol
**Pre-flight validation (mandatory)**:
- Parse the mode and any output path; reject an unrecognized mode rather than guessing.
- Execute review-workflow §3.0 context gathering.
- Confirm the diff is non-empty. An empty diff means "nothing to review", not
  "invent findings".
- For refactor modes: capture a green baseline and a rollback SHA before any edit.

**Workflow steps**:
1. Parse mode + output path.
2. Execute §3.0 context gathering.
3. **Run the automated gate first** — delegate to `build-test-runner`:
   `gofmt -l`, `go vet ./...`, `go build ./...`, `go test -race -count=1 ./...`,
   and `golangci-lint run` when available. A failing gate is the leading finding.
4. Run the selected workflow (§3.1 / §3.2 / §3.3).
5. Per-file audits via `code-quality`, using the §7.1 output contract.
6. Cross-file synthesis (§3.5), deduplicating shared root causes.
7. Generate the report (§3.6) with a verdict per §3.6.1.
8. Offer posting (§3.7) — never post unprompted.

**Checkpoints**:
- After the gate: results recorded verbatim, including versions.
- After per-file audits: every finding has a real `file:line` (re-read to confirm).
- After a refactor edit: build + tests still pass, and the test count did not drop.
- After report generation: print the absolute path and the verdict.

### §3.1 Refactor safety protocol
1. Baseline: `go test -race -count=1 ./...` must be green **before** any edit.
   If it is not, stop and report the pre-existing failure — a refactor cannot be
   validated against a red baseline.
2. Record `git rev-parse HEAD` as the rollback point.
3. Present the plan with a file count and require explicit approval.
4. Edit one file at a time; verify after each.
5. On any regression: stop immediately, report, and offer rollback. Do not
   continue through a failure.
6. A refactor that changes observable behavior is not a refactor — split it out
   and label it.

### §3.2 Post review to a PR (optional)
**Purpose**: After generating a review report, optionally post it to the PR.

**Inputs**: `mode` must be `pr:<id>`; `report_path` from §3.6.

**Workflow**:
1. After generating the report, ask:
   "Would you like to post the review summary to PR #<id>? (yes/no)"
2. If yes, collect preferences in a single prompt:
   - **Language**: English / 正體中文 / 简体中文 (default: English)
   - **Tone**: Technical / Positive / Neutral (default: Technical)
   - **Granularity**: Summary only / Summary + inline comments (default: Summary only)
   - **Include report path**: Yes / No (default: No)
   - Prompt example:
     "Ready to post the review summary to PR #<id>.
     Please specify your preferences:
     1) Language: English / 正體中文 / 简体中文 (default: English)
     2) Tone: Technical / Positive / Neutral (default: Technical)
     3) Granularity: Summary only / Summary + inline (default: Summary only)
     4) Include report path: Yes / No (default: No)
     Enter preferences (e.g. '正體中文, Positive, Summary only, No') or press Enter for defaults."
3. Generate the summary from the report according to those preferences.
4. Preview the full body and ask for final confirmation:
   "About to post to PR #<id>. Proceed? (yes/no)"
5. Delegate posting to `vcs-workflow-manager`:
   - Summary comment → VCS §3.3.1 (file-based body, read-back verification)
   - Inline comments → VCS §3.3.2, preserving each finding's `path`, `line`,
     `start_line`, `side`, `severity`, `title`, and `body`; prefer one batched
     review over N separate comments.
6. Report the resulting comment URL(s) and the read-back verification status.

**Safety**:
- MUST delegate all posting to `vcs-workflow-manager`. This skill never calls
  `gh` to write, directly.
- MUST use `event: COMMENT`. **Never** `APPROVE` or `REQUEST_CHANGES`, and
  never `gh pr merge`, without an explicit user instruction in this conversation.
- Posting is a remote write and must pass the VCS §4.1 confirmation gate.
- MUST verify the posted content by reading it back.

## §4 Delegation & Handoffs
**When to invoke other SKILLs**:

| Scenario | Delegate To | Invocation |
| --- | --- | --- |
| Automated gate (build/vet/test) | `build-test-runner` | "Run the gate with build-test-runner" |
| Per-file audit/fix | `code-quality` | "Use code-quality to audit <file>" |
| Summary comment on a PR | `vcs-workflow-manager` §3.3.1 | "Use vcs-workflow-manager to post the summary" |
| Inline review comments | `vcs-workflow-manager` §3.3.2 | "Use vcs-workflow-manager §3.3.2 to post inline findings" |
| Commit/push after a refactor | `vcs-workflow-manager` | "Help me commit using vcs-workflow-manager" |
| Package/architecture context | `project-navigator` | "Use project-navigator for module context" |

## §5 Troubleshooting
### §5.1 Common Failures
| Failure Mode | Symptoms | Root Cause | Recovery Steps |
| --- | --- | --- | --- |
| Invalid mode | Unsupported `mode` | Input parsing | Ask the user to pick from §9.1 |
| Missing PR ID | `pr:` without an id | Incomplete input | Request the PR number and retry §3.0 |
| No reviewable files | Empty diff | Branch equals base | Return early with status; do not fabricate findings |
| Branch does not build | `go build` errors | Broken branch | That IS the leading 🔴 finding; continue with static review only |
| Baseline already red | Tests fail before any edit | Pre-existing breakage | Stop the refactor; report the pre-existing failure |
| Refactor regression | Tests fail after an edit | Behavior changed | Revert that file, report, offer rollback to the recorded SHA |
| Report path invalid | `mkdir: permission denied` | Bad path | Request a writable path; do not silently relocate |
| PR too large | 100+ files | Broad change | review-workflow §6.1; state what was not reviewed in depth |
| `gh` unavailable | `command not found` | CLI missing | Fall back to `local` mode on the checked-out branch |

### §5.2 Degraded Mode Operations
| Missing Tool | Impact | Fallback Strategy |
| --- | --- | --- |
| `go` | No automated gate | Static review only; state this prominently at the top of the report |
| `golangci-lint` | Reduced static analysis | `go vet` only; record the reduced coverage in the gate table |
| `gh` | No PR data or posting | Local review on the checked-out branch; report the limitation |

## §6 Self-Assessment Checklist
- [ ] Mode and output path parsed and validated
- [ ] Context gathering completed; diff confirmed non-empty
- [ ] Automated gate run FIRST, results recorded verbatim with tool versions
- [ ] Every changed `.go` file audited against code-style-guide §10
- [ ] Every finding cites a verified `file:line`
- [ ] Cross-file synthesis performed and duplicates merged
- [ ] Verdict follows review-workflow §3.6.1
- [ ] Refactor mode: baseline green, rollback SHA recorded, plan approved
- [ ] Posting (if any) confirmed, delegated, and verified by read-back
- [ ] No APPROVE / REQUEST_CHANGES / merge performed without explicit instruction
- [ ] Next steps provided to user
