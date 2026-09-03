# tanuki: Code Review Workflow Guide

## 0. Document Structure & Navigation Guide

### 0.0 Who should use this guide
Agentic AI assistants orchestrating a review, and human developers who want the
same checklist and report format.

### 0.1 How to use this guide
Jump via §2 (decision matrix). Load §3.0 plus the one §3.x workflow that
matches. Load §7 only when delegating per-file audits.

### 0.2 Section overview

| Section | Purpose |
| --- | --- |
| §1 | Core concepts: philosophy, scope, priority, standards |
| §2 | Decision matrix (intent → workflow) |
| §3 | Common workflows (local, PR, refactor, report) |
| §4 | Safety protocol |
| §5 | Troubleshooting |
| §6 | Advanced topics (large PRs, incremental, performance) |
| §7 | Agent orchestration (delegation and synthesis) |
| §8 | Quick reference |
| §9 | Agentic AI API reference |

### 0.3 Quick navigation map

| Intent | Section |
| --- | --- |
| "review my branch" | §3.1 |
| "review PR #123" | §3.2 |
| "refactor these files" | §3.3 |
| "write the report to a file" | §3.6 |
| "post the review to the PR" | §3.7 |

### 0.4 Cross-guide reference notation
- `VCS §3.3.2` → `@.ai/contexts/vcs-workflow-guide.md` §3.3.2
- `STYLE §10` → `@.ai/contexts/code-style-guide.md` §10
- `BUILD §4` → `@.ai/contexts/build-and-test-guide.md` §4

### 0.5 Load Strategy for AI Agents
1. §3.0 context gathering — always.
2. The single matching §3.x workflow.
3. `STYLE §10` for per-file audit criteria.
4. §4 before posting anything.

---

## 1. Core Concepts

### 1.1 Review philosophy
- **Correctness first, style last.** A dropped error outranks a naming nit.
- **Cite `file:line` for every finding.** A finding without a location is an
  opinion, not a finding.
- **Explain the consequence.** "This is wrong" is not actionable; "this panics
  when the map is nil, which happens on the cold-start path" is.
- **Propose the fix.** Findings come with a concrete change.
- **Distinguish blocking from advisory.** Say plainly which is which.
- **Verify claims.** If you say the tests fail, quote the output.

### 1.2 Review scope

| In scope | Out of scope |
| --- | --- |
| Correctness, error handling, concurrency | Personal formatting preference (`gofmt` decides) |
| Resource lifecycle, leaks | Rewriting to a different architecture unasked |
| API design and exported surface | Pre-existing issues outside the diff (note them separately) |
| Test coverage of new behavior | Vendored or generated code |
| Security-relevant handling of input | — |
| Performance where it is claimed or load-bearing | Micro-optimization without a benchmark |

### 1.3 Priority system

| Priority | Definition | Action |
| --- | --- | --- |
| 🔴 Critical | Data loss, data race, panic, security hole, silent wrong result | **BLOCK** — must be fixed before merge |
| 🟡 Major | Wrong behavior in a plausible case, leaked resource, missing test for new logic | **NEEDS WORK** — fix or justify |
| 🟢 Minor | Docs, naming, clarity, minor duplication | Advisory — author's call |

### 1.4 Compliance standards
Every review checks the change against:
- `STYLE §5` — naming, error, context, and doc-comment rules
- `STYLE §10` — the full audit checklist
- `BUILD §9` — the verification checklist (build, vet, test, race)
- `VCS §1.2` — commit message policy

---

## 2. Decision Matrix (Intent → Workflow)

| Intent | Mode | Workflow | Loads |
| --- | --- | --- | --- |
| "review my branch/changes" | `local` | §3.1 | §3.0, §3.1, §7 |
| "review PR #N" / "pr:N" | `pr:<n>` | §3.2 | §3.0, §3.2, §7 |
| "refactor everything changed" | `refactor:all` | §3.3 | §3.0, §3.3, §4 |
| "refactor <file>" | `refactor:file:<path>` | §3.3 | §3.3 + STYLE §10 |
| "refactor <dir>" | `refactor:dir:<path>` | §3.3 | §3.3 + STYLE §10 |
| "just give me the report" | report only | §3.6 | §3.6 |
| "post it to the PR" | post | §3.7 | §3.7 + VCS §3.3 |

---

## 3. Common Workflows

### 3.0 Context gathering (mandatory)

```bash
REPO_ROOT=$(git rev-parse --show-toplevel) && cd "$REPO_ROOT" || exit 1

git branch --show-current
git fetch origin --quiet
git diff --stat origin/main...HEAD        # scope of the branch
git diff --name-only origin/main...HEAD   # the file list under review
git log --oneline origin/main..HEAD       # commits under review

# Tooling baseline — record versions in the report
go version 2>/dev/null || echo "go: MISSING"
command -v golangci-lint >/dev/null && golangci-lint --version || echo "golangci-lint: MISSING"
```

**Stop conditions**:
- Empty diff → report "no changes to review" and stop. Do not invent findings.
- More than ~40 changed files → §6.1 large-PR strategy before proceeding.
- Diff is entirely generated code → say so; review the generator instead.

**Record**: file list, line counts, commit list, tool versions.

### 3.1 Local branch review

```bash
BASE=origin/main
FILES=$(git diff --name-only "$BASE"...HEAD -- '*.go')
```

1. **Gather** — §3.0.
2. **Automated gate** — run and record, before reading any code:
   ```bash
   gofmt -l $FILES
   go vet ./...
   go build ./...
   go test -race -count=1 ./...
   command -v golangci-lint >/dev/null && golangci-lint run
   ```
   A failing gate is itself a 🔴 finding. Report it first.
3. **Per-file audit** — for each file in `$FILES`, apply `STYLE §10` (delegate
   per §7.1). Capture findings with `file:line`.
4. **Cross-file analysis** — §3.5.
5. **Report** — §3.6.
6. **Next actions** — list the fixes in priority order.

### 3.2 GitHub PR review

```bash
PR=<number>
REPO_SLUG=$(git remote get-url origin | sed -E 's#^[a-z+]+://##; s#^[^@]+@##; s#^[^/:]+[:/]##; s#\.git$##')

gh pr view "$PR" --json number,title,body,author,headRefName,baseRefName,state,files
gh pr diff "$PR" > /tmp/pr-"$PR".diff
gh pr checks "$PR"
gh pr view "$PR" --comments                       # existing discussion
```

1. **Gather** — the commands above, plus §3.0.
2. **Read the PR description**: does the stated intent match the diff? A
   mismatch is a 🟡 finding on its own.
3. **Check CI first.** If checks are red, the top finding is the failure; quote
   it via `gh run view <id> --log-failed`.
4. **Check out locally for a real gate** (a diff cannot be compiled):
   ```bash
   gh pr checkout "$PR"
   gofmt -l . && go vet ./... && go test -race -count=1 ./...
   ```
5. **Per-file audit** — §7.1, `STYLE §10`.
6. **Cross-file analysis** — §3.5.
7. **Report** — §3.6.
8. **Optional posting** — §3.7. Never post without confirmation.

### 3.3 Refactor workflow (multi-file)

1. **Scope** — resolve the target set:
   - `refactor:all` → `git diff --name-only origin/main...HEAD -- '*.go'`
   - `refactor:file:<path>` → that file
   - `refactor:dir:<path>` → `find <path> -name '*.go' -not -name '*_test.go'`
2. **Baseline** — capture a green state; if the tree is already failing, stop
   and say so. A refactor cannot be validated against a broken baseline.
   ```bash
   go test -race -count=1 ./... > /tmp/refactor-baseline.txt 2>&1; echo "exit=$?"
   git rev-parse HEAD > /tmp/refactor-rollback.txt
   ```
3. **Audit** — run `STYLE §10` on every target file; collect findings.
4. **Plan** — group findings into a plan by priority. **Present it and require
   explicit approval before writing anything.** State the file count.
5. **Execute** — apply approved changes file by file, behavior-preserving.
6. **Verify after every file**:
   ```bash
   gofmt -l <file> && go build ./... && go test -race -count=1 ./...
   ```
   Any regression → stop immediately, report, offer rollback to the recorded SHA.
7. **Report** — §3.3.1.

**Hard rule**: a refactor that changes observable behavior is not a refactor.
If a fix requires a behavior change, split it out and label it as such.

#### 3.3.1 Refactor summary report template

```markdown
# Refactor Summary: tanuki

## 📊 Statistics
- Files modified: N
- Lines: +A / -B
- Findings addressed: 🔴 X · 🟡 Y · 🟢 Z

## 🔧 Key Improvements
### internal/store/store.go
- `store.go:42` — wrapped the dropped error with `%w`
- `store.go:88` — added the missing doc comment on `Sweep`

## ✅ Verification Results
| Check | Before | After |
| --- | --- | --- |
| `gofmt -l .` | 3 files | clean |
| `go vet ./...` | 2 findings | clean |
| `go test -race ./...` | PASS (41) | PASS (41) |

## 📋 Files Modified
- internal/store/store.go
- internal/store/store_test.go

## 🎯 Recommendation
✅ Safe to merge — behavior preserving, test count unchanged.

## 💡 Next Steps
- <follow-up not covered by this refactor>
```

### 3.4 Parallel file analysis
For more than ~5 files, audit them independently and in parallel — each file
audit is self-contained (`STYLE §10`) and needs no shared state. Synthesize
afterwards per §3.5. Give each audit the same output contract (§7.1) so the
results can be merged mechanically.

### 3.5 Integration synthesis

After per-file audits, look for what no single-file audit can see:
- **Duplicated logic** across the changed files
- **Inconsistent error handling** — some paths wrap, others swallow
- **API/contract drift** — a signature changed in one place, callers missed
- **Layering violations** — `pkg/` importing `internal/`, `internal/` importing `cmd/`
- **Concurrency interactions** — a lock held across a call into another package
- **Test gaps at the seam** — units tested, integration untested
- **Requirements coverage** — does the diff actually deliver what the PR claims?

### 3.6 Report generation

Default output path: `${TMPDIR:-/tmp}/tanuki-review-<scope>-<timestamp>.md`.
If the user supplied a path, use it; create the parent directory first and stop
if it is not writable.

```bash
REPORT="${TMPDIR:-/tmp}/tanuki-review-$(date +%Y%m%d-%H%M%S).md"
mkdir -p "$(dirname "$REPORT")" || { echo "STOP: report path not writable"; exit 1; }
```

**Report template**:

```markdown
# Code Review Report: tanuki

**Scope**: <local branch feat/42-x | PR #123>
**Base**: origin/main @ <sha>
**Files**: N changed (+A / -B)
**Tooling**: go <version> · golangci-lint <version|absent>

## Summary
<2-4 sentences: what the change does and whether it is safe to merge>

## Automated Gate
| Check | Result |
| --- | --- |
| `gofmt -l .` | ✅ clean / ❌ <files> |
| `go vet ./...` | ✅ / ❌ <findings> |
| `go build ./...` | ✅ / ❌ |
| `go test -race -count=1 ./...` | ✅ PASS (N) / ❌ <failing tests> |
| `golangci-lint run` | ✅ / ❌ (N findings) / ⚠️ not installed |

## Requirements Coverage
| Stated intent | Delivered | Evidence |
| --- | --- | --- |
| <from the PR description> | ✅/⚠️/❌ | `file:line` |

## File-Level Issues

### 🔴 Critical (N)
- `internal/store/store.go:42` — <finding>.
  **Impact**: <consequence>. **Fix**: <concrete change>.

### 🟡 Major (N)
- `internal/store/store.go:88` — <finding>. **Fix**: <change>.

### 🟢 Minor (N)
- `internal/store/store.go:12` — <finding>.

## Cross-File Analysis
- <duplication, inconsistency, layering, contract drift>

## Architectural Impact
- <API surface changes, new dependencies, layering effects>

## Recommendation
✅ APPROVE | 🟡 NEEDS WORK | 🔴 BLOCK

<one paragraph justifying the verdict>

## Next Steps
1. <ordered, actionable>
```

#### 3.6.1 Verdict rules
- Any 🔴 → **BLOCK**.
- Any 🟡, or a failing automated gate → **NEEDS WORK**.
- Only 🟢 → **APPROVE** (advisory notes remain the author's call).

### 3.7 Posting the review to a PR

**Delegate all posting to the `vcs-workflow-manager` skill.** This workflow
never calls `gh` to write, directly.

1. Generate the report (§3.6) first.
2. Ask: "Post the review summary to PR #<n>? (yes/no)"
3. If yes, collect preferences in a single prompt:
   - **Language**: English / 正體中文 / 简体中文 (default: English)
   - **Tone**: Technical / Positive / Neutral (default: Technical)
   - **Granularity**: Summary comment only / Summary + inline comments (default: summary only)
   - **Include report path**: Yes / No (default: No)
4. Generate the comment body, preview it in full, and ask for final confirmation.
5. Hand off:
   - Summary comment → `vcs-workflow-manager`, VCS §3.3.1
   - Inline comments → `vcs-workflow-manager`, VCS §3.3.2, preserving each
     finding's `path`, `line`, `start_line`, `side`, `severity`, and `body`
6. Report the resulting comment URL(s) and the read-back verification status.

**Safety**:
- An agent never posts `APPROVE` or `REQUEST_CHANGES` — only `COMMENT` — unless
  the user explicitly instructs otherwise in the current conversation.
- Posting is a remote write and must pass the VCS §4.1 confirmation gate.
- Verify the posted content by reading it back (VCS §3.3.1 step 4).

---

## 4. Safety Protocol

### 4.1 Pre-flight checks
- [ ] §3.0 context gathering done; diff is non-empty
- [ ] Tool versions recorded
- [ ] Baseline test state captured (for refactor modes)
- [ ] Rollback SHA recorded (for refactor modes)
- [ ] Report output path is writable

### 4.2 Confirmation gates

| Action | Gate |
| --- | --- |
| Read code, run read-only checks | None |
| Write a report to a temp file | None |
| Modify source files (refactor) | ✅ Plan approved first, file count stated |
| Post any comment to a PR | ✅ Full body previewed and confirmed |
| Submit APPROVE / REQUEST_CHANGES | 🚫 Refuse unless explicitly instructed |
| `gh pr merge` | 🚫 Out of scope for this workflow |

### 4.3 Verification
- Every finding cites a real `file:line` — re-read the file to confirm.
- Every claim about test results quotes actual output.
- After a refactor: the test count must not silently drop.
- After posting: read the comment back and compare.

---

## 5. Troubleshooting

| Failure | Symptom | Cause | Recovery |
| --- | --- | --- | --- |
| §5.1 No changes | `git diff` empty | Branch equals base, or already merged | Report and stop; do not fabricate findings |
| §5.2 Auth failure | HTTP 401 from `gh` | Token expired | VCS §5.3; ask the user to `gh auth login` |
| §5.3 Build fails during audit | `go build` errors | The branch is broken | That IS the top 🔴 finding; report it and continue with static review only |
| §5.4 Network failure | `gh` timeout | Offline / proxy | Fall back to `local` mode on the checked-out branch |
| §5.5 Baseline already red | Tests fail before any change | Pre-existing breakage | Stop the refactor; report the pre-existing failure first |
| §5.6 Refactor breaks tests | Regression after an edit | Behavior changed | Revert that file; report; do not continue blindly |
| §5.7 Missing tooling | `golangci-lint: not found` | Not installed | Degrade to `go vet`; state the reduced coverage in the report |
| §5.8 Report path unwritable | `mkdir: permission denied` | Bad path | Ask for a writable path; do not silently relocate |
| §5.9 PR too large | 100+ files | Broad change | §6.1 |

---

## 6. Advanced Topics

### 6.1 Large PRs
1. Group the files by package and review package by package.
2. Prioritize: `cmd/` wiring and exported `pkg/` APIs first, tests last.
3. Report per-package, then synthesize.
4. Say explicitly what you did **not** review in depth. An honest partial
   review beats a fake complete one.

### 6.2 Incremental review (diff-only)
For a re-review after the author pushed fixes:
```bash
git diff <last-reviewed-sha>...HEAD
gh pr view "$PR" --json commits -q '.commits[].oid'
```
Review only the delta, but re-run the full automated gate — a local fix can
break a distant package.

### 6.3 Performance-sensitive changes
Do not accept a performance claim without evidence:
```bash
go test -bench=. -benchmem -run='^$' ./... > /tmp/after.txt
git stash && go test -bench=. -benchmem -run='^$' ./... > /tmp/before.txt && git stash pop
benchstat /tmp/before.txt /tmp/after.txt   # if benchstat is installed
```
A refactor that claims a speedup without a benchmark gets a 🟡 finding.

---

## 7. Agent Orchestration

### 7.1 File audit delegation

Give each delegated audit exactly this contract:

**Input**: one file path, the diff hunks for it, and `STYLE §10`.
**Output**:

```markdown
### 📄 File: <path>

**Lines reviewed**: <range or "full file">
**Automated**: gofmt <ok/fail> · vet <ok/fail> · lint <n findings>

#### 🔴 Critical (N)
- `<file>:<line>` — <finding>. **Impact**: <x>. **Fix**: <y>.

#### 🟡 Major (N)
- `<file>:<line>` — <finding>. **Fix**: <y>.

#### 🟢 Minor (N)
- `<file>:<line>` — <finding>.

**File verdict**: ✅ / 🟡 / 🔴
```

**Rules for delegated audits**: cite `file:line` or do not report it; do not
modify files in audit mode; do not review files you were not given.

### 7.2 Integration synthesis

Merge the per-file results into:

```markdown
## 📋 Requirements Coverage
<stated intent vs delivered, with evidence>

## 🔗 Cross-File Issues
<duplication, inconsistent error handling, contract drift>

## 🏗️ Architectural Impact
<layering, exported surface, new dependencies>

## 🎯 Recommendation: <✅ APPROVE | 🟡 NEEDS WORK | 🔴 BLOCK>
```

Deduplicate: the same root cause appearing in five files is **one** finding
with five locations, not five findings.

---

## 8. Quick Reference

### 8.1 Review checklist
- [ ] Automated gate run and recorded (`gofmt`, `vet`, `build`, `test -race`, lint)
- [ ] Every changed `.go` file audited against `STYLE §10`
- [ ] Error handling: wrapped, checked, never dropped
- [ ] Concurrency: no leaked goroutines, `-race` clean
- [ ] Resources: every open has a close
- [ ] Exported surface documented (`STYLE §5.4`)
- [ ] New behavior has a test, including error paths
- [ ] Cross-file synthesis done
- [ ] Every finding cites `file:line`
- [ ] Verdict follows §3.6.1
- [ ] Next steps are ordered and actionable

### 8.2 Priority decision tree
```
Finding
 ├─ Can it lose data, race, panic, or leak a secret?     → 🔴 Critical
 ├─ Will it produce a wrong result in a plausible case?  → 🔴 Critical
 ├─ Does it leak a resource or drop an error?            → 🟡 Major
 ├─ Is new logic untested?                               → 🟡 Major
 ├─ Does it break a documented API contract?             → 🟡 Major
 └─ Otherwise (naming, docs, clarity)                    → 🟢 Minor
```

---

## 9. Agentic AI API Reference

### 9.1 Workflow entry points

| Mode | Argument | Entry |
| --- | --- | --- |
| Local review | `local` | §3.1 |
| PR review | `pr:<n>` | §3.2 |
| Refactor all | `refactor:all` | §3.3 |
| Refactor file | `refactor:file:<path>` | §3.3 |
| Refactor dir | `refactor:dir:<path>` | §3.3 |
| Report path override | trailing path, or "save to <path>" | §3.6 |

### 9.2 Output schemas

**Finding**:
```json
{
  "file": "internal/store/store.go",
  "line": 42,
  "start_line": null,
  "side": "RIGHT",
  "severity": "critical|major|minor",
  "title": "dropped error",
  "body": "<explanation + fix>",
  "category": "correctness|concurrency|resource|api|performance|test|docs"
}
```

**Review result**:
```json
{
  "scope": "pr:123",
  "base_sha": "<sha>",
  "files_reviewed": 7,
  "gate": {"gofmt": "pass", "vet": "pass", "build": "pass", "test": "pass", "lint": "skipped"},
  "findings": [ /* Finding[] */ ],
  "verdict": "approve|needs_work|block",
  "report_path": "/tmp/tanuki-review-20260903-101500.md"
}
```

### 9.3 Intent routing

```
Input
 ├─ "local" | "my branch" | "my changes"        → §3.1
 ├─ "pr:<n>" | "PR #<n>" | "review pull request" → §3.2
 ├─ "refactor:*" | "refactor ..."               → §3.3
 ├─ "report only"                               → §3.6
 ├─ "post to PR"                                → §3.7
 └─ unrecognized                                → ask for a valid mode (§9.1)
```
