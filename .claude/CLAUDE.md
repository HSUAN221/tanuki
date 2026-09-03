# Repository Guide for Coding Agents

## 🚨 CRITICAL SYSTEM PROMPT (READ FIRST - MANDATORY FOR ALL AI AGENTS)
You are operating in the **tanuki repository** with a **SKILL-FIRST architecture**.

### ⚠️ MANDATORY EXECUTION RULES
**RULE 1: SKILL-FIRST ROUTING**
Before executing ANY user request, you MUST:
1. ✋ STOP and check the Decision Tree below
2. 🔍 Match user intent against SKILL patterns
3. ✅ If match found → Load and execute via SKILL
4. ❌ If no match → Proceed with direct tools

**RULE 2: FORBIDDEN DIRECT OPERATIONS**
The following operations are FORBIDDEN via direct bash/tools:
- ❌ `git commit`, `git push`, `git branch` → Use `vcs-workflow-manager`
- ❌ `gofmt -w`, `goimports -w`, `golangci-lint` → Use `code-quality`
- ❌ Manual code review → Use `code-reviewer`
- ❌ `go build`, `go test`, `go vet` → Use `build-test-runner`

**RULE 3: CONTEXT DRIFT PREVENTION**
In long conversations:
- 🔄 Re-check Decision Tree before EVERY VCS/quality/review operation
- 📋 When using TODO lists, add "Check SKILL routing" as first step
- 🛡️ If unsure, default to SKILL (safer)

**RULE 4: VIOLATION HANDLING**
If you realize you violated SKILL-FIRST rules:
1. Acknowledge the error immediately
2. Explain what happened (context drift, oversight, etc.)
3. Offer to redo with correct SKILL
4. Do NOT proceed without user confirmation

### 🎯 Why This Matters
SKILLs provide:
- ✅ Safety gates (confirmation, validation)
- ✅ Policy enforcement (commit format, branch naming)
- ✅ Consistent workflows
- ✅ Error recovery mechanisms

**Bypassing SKILLs = Violating repository safety standards.**

## ⚙️ Path Conventions (CRITICAL: read before opening any files)

**All `@...` paths are repo-root-relative.**

- Repo root: `../` (one level up from this file)

**Resolve examples:**
- `@.ai/contexts/project-overview.md` → `../.ai/contexts/project-overview.md`
- `@.ai/contexts/code-style-guide.md` → `../.ai/contexts/code-style-guide.md`

**If your tool resolves paths relative to this directory, prepend `../` when opening.**
Full rules: `@.ai/contexts/path-conventions.md`

---

## 🚀 Quick Start (read after path conventions)

**Required first read:** `@.ai/contexts/project-overview.md` (resolve via path rules above)

**Use skills for all workflows.** Skills are self-contained and load their own guides.

| Skill | When to use | How to invoke |
| --- | --- | --- |
| `project-navigator` | Architecture/dependency lookup | `/project-navigator <query>` |
| `build-test-runner` | Build/test with the Go toolchain | `/build-test-runner <action>` |
| `vcs-workflow-manager` | Commit/push/PR/branch/CI/inline review comments | `/vcs-workflow-manager <action>` |
| `code-quality` | Format/validate/lint/audit/fix Go code | `/code-quality <action>` |
| `code-reviewer` | Code review/refactor orchestration | `/code-reviewer <mode> [path]` |

**Terminology glossary:** `@.ai/contexts/terminology.md`

**Quick Start Example**
```
User: "Run the tests with the race detector"
Assistant: /build-test-runner test
```

**Decision tree (🔒 MANDATORY - check before EVERY action):**
**ENFORCEMENT LEVEL**: 🔴 CRITICAL - Violations will be flagged by user.
```
User request
 ├─ Commit/PR/push/branch/CI/issue → 🔒 MUST use vcs-workflow-manager
 │   ├─ Keywords: commit, push, pull, merge, branch, PR, MR, issue, CI, release, tag
 │   └─ ❌ FORBIDDEN: Direct git commit, git push, gh commands
 │
 ├─ Inline/line-level review comment → 🔒 MUST use vcs-workflow-manager §3.2.2
 │   ├─ Keywords: inline, line-level, 行內留言, 區塊留言, inline comment, positional comment
 │   └─ Write operation: never treat as read-only Query issue/PR info
 │
 ├─ Query issue/PR info (info, number, list, show) → 🔒 MUST use vcs-workflow-manager
 │   └─ Exception: Read-only git status, git log allowed
 │
 ├─ Review workflow (branch/PR) → 🔒 MUST use code-reviewer
 │   ├─ Keywords: review, code review, PR review, local review
 │   └─ ❌ FORBIDDEN: Manual file-by-file review without SKILL
 │
 ├─ Single-file audit/fix → 🔒 MUST use code-quality
 │   ├─ Keywords: audit, fix, format, lint, doc comment, gofmt
 │   └─ ❌ FORBIDDEN: Direct gofmt -w, goimports -w, golangci-lint without SKILL
 │
 ├─ Build/test/coverage/benchmark → 🔒 MUST use build-test-runner
 │   ├─ Keywords: build, test, go test, go build, race, coverage, benchmark
 │   └─ ❌ FORBIDDEN: Direct go build, go test, go vet without SKILL
 │
 ├─ Refactor multiple files → 🔒 MUST use code-reviewer
 │   ├─ Keywords: refactor, refactor all, refactor dir
 │   └─ Delegates to code-quality for execution
 │
 ├─ Module/dependency lookup → 🔒 MUST use project-navigator
 │   └─ Keywords: where is, find package, dependency, go.mod
 │
 └─ Other → Ask clarifying question
```

**✅ ALLOWED DIRECT OPERATIONS (Exceptions)**:
- Read-only Git queries: `git status`, `git log`, `git diff`, `git branch --show-current`
- File system operations: `cat`, `ls`, `find`, `grep`, `rg`
- Read-only Go queries: `go version`, `go env`, `go list`, `go doc`
- Read-only format check: `gofmt -l`, `gofmt -d` (never `-w`)
- Environment checks: `which`, `command -v`
- Temporary debugging: `echo`, `pwd`, `env`

**❌ NEVER ALLOWED DIRECT OPERATIONS**:
- Any `git commit`, `git push`, `git pull`, `git merge`, `git tag`
- Any `gofmt -w`, `goimports -w`, `golangci-lint run` (use code-quality)
- Any `go build`, `go test`, `go vet`, `go mod tidy` (use build-test-runner)
- Any `gh pr`, `gh issue`, `gh release` (use vcs-workflow-manager)
- Any `gh api --method POST/PATCH/PUT/DELETE` (use vcs-workflow-manager)

**🔍 HOW TO CHECK**:
Before executing, ask yourself:
1. Does this operation modify repository state? → Check if SKILL exists
2. Does this operation enforce policy? → MUST use SKILL
3. Is this a read-only query? → Direct tools OK

**Read strategy:** Only read extra references if the selected skill asks for it.

---

## 🔴 Repository Hard Rules (never bypass)

1. **Never commit directly to `main`.** Every change lands via a pull request.
2. **`gofmt` clean is non-negotiable.** `gofmt -l .` must print nothing.
3. **`go vet ./...` and `go test ./...` must pass before any push.**
4. **`gofmt -l` exits 0 even when files are unformatted** — gate on empty
   output (`test -z "$(gofmt -l .)"`), never on the exit code.
5. **Never `git push --force`.** Use `--force-with-lease`, on your own branch only.
6. **Never post `APPROVE` or `REQUEST_CHANGES` on a PR**, and never
   `gh pr merge`, without an explicit instruction from the user.
7. **Write PR/issue/comment bodies to a file** and pass `--body-file`. Inline
   Markdown lets the shell execute backticks.
8. **A remote write is not done until it is read back.** HTTP 200 is not verification.
9. **Query facts, never recall them.** Go version, dependencies, and branch
   state come from `go.mod`, `go list`, and `git` — not from memory.

---

## Post-Action Self-Check Protocol
**MANDATORY**: After completing ANY user request, execute this checklist:

### Checklist
```python
# Pseudo-code for AI self-reflection
def post_action_check(action_taken, user_request):
    operation_type = classify_operation(action_taken)
    required_skill = check_decision_tree(user_request)

    if required_skill and not used_skill(action_taken):
        return {
            "status": "VIOLATION",
            "expected": required_skill,
            "actual": "direct bash/tools",
            "action": "NOTIFY_USER"
        }

    return {"status": "COMPLIANT"}
```

### Self-Check Questions
After EVERY action, ask yourself:
1. Did I execute a VCS operation?
   - git commit, git push, git branch, gh commands?
   - → Should I have used vcs-workflow-manager? ✅/❌
2. Did I execute a code quality operation?
   - gofmt -w, goimports, golangci-lint?
   - → Should I have used code-quality? ✅/❌
3. Did I execute a review operation?
   - Manual file review, multi-file analysis?
   - → Should I have used code-reviewer? ✅/❌
4. Did I execute a build/test operation?
   - go build, go test, go vet?
   - → Should I have used build-test-runner? ✅/❌

### Violation Response Template
If you detect a violation, immediately respond:
```
⚠️ SELF-CHECK ALERT: Potential SKILL violation detected
What I did: [Describe action]
What I should have done: Use [SKILL-name]
Why it matters: [Safety/policy implication]
Options:
1. ✅ Redo with correct SKILL (recommended)
2. ⏭️ Continue (if user explicitly prefers direct approach)
Would you like me to redo this operation using the correct SKILL?
```

### Exception Handling
When self-check is NOT needed:
- Read-only operations (git status, cat, ls, go list)
- User explicitly requested "manual mode"
- Operation is outside SKILL scope (per Decision Tree)

---

## Long Conversation Protocol (Context Drift Prevention)
### Problem Statement
In long conversations (>10 exchanges), AI attention may drift from initial rules to task details, causing SKILL bypass violations.

### Prevention Strategies
#### Strategy 1: Periodic Rule Refresh
**Trigger points** (re-read Decision Tree):
- Before EVERY VCS operation (commit, push, branch)
- Before EVERY code quality operation (format, lint, fix)
- Before EVERY review operation (local, PR, refactor)
- After completing a TODO list (before next user request)

#### Strategy 2: TODO List Integration
When creating TODO lists, ALWAYS include:
```
TODO List
- [ ] Pre-flight check: Verify SKILL routing for this task
- [ ] Task 1: [Actual task]
- [ ] Task 2: [Actual task]
- [ ] Post-flight check: Self-check for SKILL violations
```

#### Strategy 3: Checkpoint Reminders
Before executing high-risk operations, insert a mental checkpoint:
```
User request: "git add and commit"
  ↓
[CHECKPOINT] Is this a VCS operation? → YES
  ↓
[CHECKPOINT] Check Decision Tree → Commit → vcs-workflow-manager
  ↓
[CHECKPOINT] Load SKILL → vcs-workflow-manager
  ↓
Execute via SKILL
```

#### Strategy 4: Context Window Management
When the context window is large (>50k tokens):
- Prioritize SYSTEM PROMPT and Decision Tree in attention
- Explicitly re-state rules before critical operations
- Use visual markers (🔒 MUST) to maintain salience

### Self-Monitoring Metrics
Track your own performance:
- ✅ Consecutive SKILL-compliant operations: count
- ❌ Violations detected: count
- 🔄 Self-corrections made: count
Goal: Zero violations in production usage.

---

## Reference (read only when needed)

<details>
<summary>Skill details (purpose + skip rules)</summary>

### `project-navigator`
- **Use when:** architecture questions, package location, dependency lookups
- **Skip when:** simple file lookup or single-file inspection

### `build-test-runner`
- **Use when:** `go build` / `go test` / `go vet` / coverage / benchmarks / cross-compilation
- **Required:** for all build and test operations

### `vcs-workflow-manager`
- **Use when:** commit, push, PR, issues, branch, CI status, releases
- **Required:** for all VCS operations

### `code-quality`
- **Use when:** formatting Go, lint remediation, doc comments, single-file audits and fixes
- **Required:** for style/formatting/lint/audit operations

### `code-reviewer`
- **Use when:** branch or PR review, multi-file refactor orchestration
- **Skip when:** a single file needs an audit — use `code-quality`

</details>

<details>
<summary>Context guides (source of truth)</summary>

| Guide | Covers |
| --- | --- |
| `@.ai/contexts/project-overview.md` | Identity, mission, tech stack, constraints |
| `@.ai/contexts/path-conventions.md` | Path resolution for docs and shell |
| `@.ai/contexts/terminology.md` | Canonical vocabulary |
| `@.ai/contexts/codebase-guide.md` | Repository layout, package architecture |
| `@.ai/contexts/dependency-map.md` | `go.mod` queries and dependency policy |
| `@.ai/contexts/build-and-test-guide.md` | Go build, test, coverage, cross-compilation |
| `@.ai/contexts/code-style-guide.md` | Formatting, naming, idioms, audit checklist |
| `@.ai/contexts/vcs-workflow-guide.md` | Git + GitHub workflows and safety protocol |
| `@.ai/contexts/review-workflow.md` | Review and refactor orchestration |
| `@.ai/contexts/issue-workflow-guide.md` | Issue templates, routing, closure |

</details>

<details>
<summary>Usage examples</summary>

```
/vcs-workflow-manager commit
/build-test-runner test
/code-quality audit
/code-reviewer local
/code-reviewer pr:123 /tmp/pr-123-review.md
```

</details>

<details>
<summary>Maintenance notes (for repository maintainers)</summary>

- `.claude/` is the **canonical** copy. `.codex/`, `.gemini/`, and `.opencode/`
  are generated by `scripts/sync-ai-config.sh`.
- Edit `.claude/CLAUDE.md` and `.claude/skills/`, then run:
  `./scripts/sync-ai-config.sh`
- Verify without writing: `./scripts/sync-ai-config.sh --check`
- Add a new skill → update the skill table + decision tree here, then re-sync.
- Update `.ai/contexts/` when a policy changes; skills reference sections by
  ID (§X.Y), so renumbering a section means updating its referrers.

</details>
