---
name: code-quality
description: |
  Enforce tanuki Go formatting, doc comments, lint compliance, and naming
  conventions using the code-style guide. Use when formatting code, validating
  style before commits/PRs, performing single-file code audits, or auto-fixing
  issues identified by an audit.
argument-hint: |
  [optional: format | validate | lint | audit | fix | docs | rules | templates | help]
  - format: Apply gofmt -s + goimports to Go files
  - validate: Dry-run checks without modifying files
  - lint: Run golangci-lint and triage findings
  - audit: Comprehensive single-file analysis (format + docs + correctness + concurrency)
  - fix: Auto-fix issues found in an audit (semantic changes + docs + format)
  - docs: Generate/repair doc comments on exported identifiers
  - rules: Answer style rules without executing commands
  - templates: Provide copy-ready Go templates without executing commands
  - help: Show routing table and guide references
invocation-syntax: |
  opencode: /code-quality format
---

# Code Quality

## §0 When to Use This Skill
### §0.1 Section Overview

| Section | Purpose |
| --- | --- |
| §1 Routing & Classification | Map user intent to the code-style guide |
| §2 Load Strategy | Select the minimum authoritative context |
| §3 Execution Protocol | Execute and verify formatting, lint, or audit workflows |
| §4 Delegation & Handoffs | Route work to related skills |
| §5 Troubleshooting | Recover from tool and workflow failures |
| §6 Self-Assessment Checklist | Confirm routing, execution, and verification |

**Use this skill when**:
- The user requests Go formatting, style checks, or doc-comment fixes.
- The user wants pre-commit or CI-style validation without modifications.
- The user asks for lint triage or `golangci-lint` remediation.
- The user requests a comprehensive audit or auto-fix for a file.

**Do NOT use this skill when**:
- The request is unrelated to formatting/style/lint/audit.
- The request covers a whole branch or PR (delegate to `code-reviewer`).
- The user explicitly wants manual steps only (provide commands, skip orchestration).

## §0.5 Anti-Patterns (What NOT to Do)
❌ **WRONG: Direct formatting without SKILL**

**Scenario**: User says "format internal/store/store.go"
```
gofmt -w internal/store/store.go
```

**Problems**:
1. Skips pre-flight validation (§3.0) — no record of the pre-existing dirty state.
2. No diff preview, so the user cannot see what will change before it changes.
3. Misses `-s` (simplification) and `goimports` (import grouping), so the next
   contributor's run produces a spurious diff.
4. No verification that the file still builds.

✅ **CORRECT: Use this skill**
```
Use the `code-quality` skill to format the requested file.
```

**What this provides**:
1. Pre-flight validation (§3.0).
2. Correct tool sequencing: `gofmt -d` preview → `gofmt -s -w` → `goimports -w` → verify.
3. Confirmation before modifying files.
4. Verification via `gofmt -l`, `go build`, and `git diff --stat`.

## §0.6 Why This Matters
**Safety implications**:

| Aspect | Direct Bash | This SKILL |
| --- | --- | --- |
| Pre-flight validation | ❌ None | ✅ Enforced |
| Tool ordering | ❌ Manual | ✅ Standardized |
| Confirmation gate | ❌ None | ✅ Required for writes |
| Verification checks | ❌ None | ✅ Required |
| Doc-comment compliance | ❌ Inconsistent | ✅ Guided (§5.4) |

**Real-world consequences**:
- 🚨 Inconsistent formatting → CI style failures and noisy diffs.
- 🚨 Missing doc comments on exported identifiers → `go doc` output is useless.
- 🚨 A "format" that silently changed semantics → a bug shipped as whitespace.

## §0.7 Anti-Patterns: Go tooling pitfalls
❌ **Gating on `gofmt -l`'s exit code**
```bash
gofmt -l . && echo clean     # prints "clean" even when files are unformatted
```
✅ `test -z "$(gofmt -l .)"` — `gofmt -l` exits 0 regardless of findings.

❌ **Formatting after staging, then committing**
```bash
git add file.go && gofmt -w file.go && git commit   # commits the UNFORMATTED version
```
✅ Re-stage after formatting: `gofmt -s -w file.go && git add file.go`.

❌ **Blanket-disabling a linter**
```yaml
linters: { disable: [errcheck] }
```
✅ A narrow, justified inline directive: `//nolint:errcheck // best-effort close on the read path`.

❌ **Running `gofmt` on a file that does not parse**
`gofmt` cannot format invalid syntax; fix the compile error first.

## §0.8 Path Conventions (read first)
See `@.ai/contexts/path-conventions.md`.

## §1 Routing & Classification
**User intent → Guide section mapping**:

| User Intent | Interpret As | Jump to Guide Section |
| --- | --- | --- |
| "Show quick commands" | Quick reference | `@.ai/contexts/code-style-guide.md` → **§1** |
| "What rules apply?" | Rules-only query | `@.ai/contexts/code-style-guide.md` → **§5** |
| "Give me a template" | Templates-only query | `@.ai/contexts/code-style-guide.md` → **§6** |
| "Format this file" | Single-file formatting | `@.ai/contexts/code-style-guide.md` → **§3.1** |
| "Format staged files" | Pre-commit formatting | `@.ai/contexts/code-style-guide.md` → **§3.2** |
| "Check formatting only" | Validation (dry-run) | `@.ai/contexts/code-style-guide.md` → **§3.3** |
| "Format the whole package" | Bulk formatting | `@.ai/contexts/code-style-guide.md` → **§3.4** |
| "Fix the doc comments" | Documentation remediation | `@.ai/contexts/code-style-guide.md` → **§3.5** |
| "Run the linter" | Lint remediation | `@.ai/contexts/code-style-guide.md` → **§3.6** |
| "Audit this file" | Comprehensive audit | `@.ai/contexts/code-style-guide.md` → **§10** |
| "Fix the issues in this file" | Auto-fix | `@.ai/contexts/code-style-guide.md` → **§10** + this skill §3.1 |

## §1.5 Quick Decision Tree (for AI routing)
```
User request received
 ├─ Query-only → Load §1/§5/§6 → Respond without execution
 ├─ "format" + single file → Load §3.0 + §3.1 → Execute guide workflow
 ├─ "format" + staged files → Load §3.0 + §3.2 → Execute guide workflow
 ├─ "validate" / "dry-run" / "CI check" → Load §3.0 + §3.3 → Read-only
 ├─ "lint" → Load §3.0 + §3.6 → Execute, then triage findings
 ├─ "audit" / "review this file" → Load §3.0 + §3.3 + §10 → Report only
 ├─ "fix" / "clean up this file" → Load §3.0 + §10 → Plan → CONFIRM → Apply → Re-audit
 ├─ "bulk" / "directory" → Load §3.0 + §3.4 → Show blast radius → CONFIRM
 ├─ "docs" / "comments" → Load §3.0 + §3.5 + §6 → Execute
 └─ Unclear → Ask a clarifying question using the §1 table
```

## §2 Load Strategy
**Authoritative references**:
- Primary guide → `@.ai/contexts/code-style-guide.md`

**On-demand load map**:
- Quick commands → §1
- Rules-only query → §5
- Templates-only query → §6
- Formatting/validation execution → §3.0 + the relevant §3.x
- Comprehensive audit → §3.0 + §3.3 + §10
- Auto-fix → §3.0 + §3.5 + §10
- Bulk formatting → §3.4 + §4
- Troubleshooting → §7
- Tooling lookup → §8

## §3 Execution Protocol
**Pre-flight validation (mandatory)**:
- Execute **§3.0 Pre-flight validation** in `@.ai/contexts/code-style-guide.md`.
- Record `git status --porcelain` so your changes are distinguishable from the
  user's pre-existing edits.
- Record `git rev-parse HEAD` as a rollback point.

**Workflow steps**:
1. Classify the request using §1.
2. Load the required guide sections.
3. Preview actions (files, commands, expected changes) — `gofmt -d` for formatting.
4. Require explicit confirmation for write and bulk operations.
5. Execute the guide workflow.
6. Verify: `gofmt -l` empty, `go build ./...` passes, `git diff --stat` matches
   the announced scope.

**Checkpoints**:
- After a write: the file still compiles. A format that breaks the build failed.
- After a bulk format: the diff is whitespace and imports only — if it is not,
  revert and investigate.

### §3.1 Fix workflow (auto-refactor)
**Purpose**: Automatically fix issues identified in audit mode for a single file.

**Inputs**:
- `file`: path to a single file
- `plan` (optional): a pre-approved fix plan

**Workflow**:
1. If no plan is provided:
   - Run audit mode (guide §10) on the target file.
   - Convert findings into a plan grouped by priority (🔴 / 🟡 / 🟢).
   - **Present the plan and require approval before modifying anything.**
2. Execute the approved plan:
   - Apply semantic fixes (error wrapping, resource closing, nil guards,
     concurrency corrections) per guide §10.2–§10.7.
   - Add missing doc comments per guide §5.4 + §6.
   - Format last: `gofmt -s -w` → `goimports -w`.
3. Verification:
   - `go build ./...` and `go test -race -count=1 ./...` must pass.
   - Re-run the audit on the modified file.
   - If a new 🔴 finding appears, STOP and offer rollback to the recorded SHA.

**Safety**:
- MUST obtain explicit user confirmation before writing.
- MUST NOT change observable behavior unless the fix *is* the behavior change,
  in which case say so explicitly in the plan.
- MUST verify no new 🔴 finding was introduced.

**Output**: updated file + summary of changes + verification status.

## §4 Delegation & Handoffs
**When to invoke other SKILLs**:

| Scenario | Delegate To | Invocation |
| --- | --- | --- |
| Multi-file or branch-wide refactor | `code-reviewer` | "Use code-reviewer for refactor:all" |
| Branch or PR review | `code-reviewer` | "Use code-reviewer for a local review" |
| Commit/push after formatting | `vcs-workflow-manager` | "Help me commit using vcs-workflow-manager" |
| Build/test validation | `build-test-runner` | "Run tests with build-test-runner" |
| "Where does this belong?" | `project-navigator` | "Use project-navigator for placement" |

## §5 Troubleshooting
### §5.1 Common Failures
| Failure Mode | Symptoms | Root Cause | Recovery Steps |
| --- | --- | --- | --- |
| Missing gofmt | `command not found` | Go toolchain absent | Report and stop; do not hand-format |
| Parse failure | `expected ';', found '}'` | The file does not compile | Fix the syntax error first; `gofmt` cannot format invalid Go |
| goimports drops an import | Build breaks after formatting | Import only used under a build tag | Pass the tag, or keep it as `_ "path"` if it is for side effects |
| Import grouping flip-flops | Diff churn between contributors | `gofmt` (2 groups) vs `goimports` (3) | Standardize on `goimports -local github.com/HSUAN221/tanuki` |
| `//nolint` ignored | Finding persists | Directive not on the finding's line, or linter not named | `//nolint:<linter> // reason` on the exact line |
| golangci-lint disagrees with CI | Different findings locally | Version drift | Pin the version; report the version in every result |
| Unsupported file type | Extension not `.go` | Out-of-scope target | Explain the scope (§2 of the guide) and stop |

### §5.2 Degraded Mode Operations
| Missing Tool | Impact | Fallback Strategy |
| --- | --- | --- |
| `gofmt` | Cannot format | Provide guidance only; request the Go toolchain |
| `goimports` | Imports ungrouped | Use `gofmt` only; note the reduced import handling |
| `golangci-lint` | Reduced static analysis | Fall back to `go vet`; state the reduced coverage in the report |

## §6 Self-Assessment Checklist
- [ ] Request classified with guide section references
- [ ] Required guide sections loaded and cited
- [ ] Pre-flight validation completed (per guide §3.0)
- [ ] Pre-existing dirty state and rollback SHA recorded
- [ ] Diff previewed before any write
- [ ] Confirmation obtained for write/bulk operations
- [ ] Commands executed with stdout/stderr captured
- [ ] `gofmt -l` verified empty (not merely exit code 0)
- [ ] `go build ./...` still passes after the change
- [ ] Next steps provided to user
