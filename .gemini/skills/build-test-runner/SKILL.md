---
name: build-test-runner
description: Plan and execute tanuki Go build, test, coverage, and benchmark flows safely.
argument-hint: "[optional: build | test | race | coverage | bench | vet | tidy | cross | environment | troubleshoot]"
invocation-syntax: |
  gemini: activate_skill build-test-runner test
---

# Build & Test Runner

## §0 When to Use This Skill
**Use this skill when**:
- The user asks to build, compile, test, vet, or benchmark.
- The user asks for coverage, a race-detector run, or a cross-compiled binary.
- The user needs environment validation (`go version` vs the `go.mod` directive).
- The user reports build/test failures that need structured recovery.

**Do NOT use this skill when**:
- The request is unrelated to build/test operations.
- The user explicitly requests manual commands only (provide commands, skip orchestration).

## §0.5 Anti-Patterns (What NOT to Do)
❌ **WRONG: Direct Go commands without SKILL**

**Scenario**: User says "run the tests"
```
go test ./...
```

**Problems**:
1. Skips the setup checklist (§2 of the build guide) — no toolchain/version validation.
2. Trusts the test result cache; a stale PASS looks identical to a real one.
3. No race detector, so concurrency bugs pass silently.
4. cwd may be a subdirectory, so `./...` silently under-matches.
5. No checkpoint evidence, and no guided recovery on failure.

✅ **CORRECT: Use this skill**
```
Use the `build-test-runner` skill to run the test suite.
```

**What this provides**:
1. Setup checklist enforcement and Go version validation.
2. The right invocation for the intent (`-count=1`, `-race`, `-run` anchoring).
3. Checkpointed build/vet/test reporting with real output.
4. Guided recovery using the troubleshooting matrix.

## §0.6 Why This Matters
**Safety implications**:

| Aspect | Direct Bash | This SKILL |
| --- | --- | --- |
| Environment validation | ❌ None | ✅ Required |
| Test cache awareness | ❌ Stale PASS | ✅ `-count=1` when it matters |
| Race detection | ❌ Skipped | ✅ Required for concurrent code |
| cwd correctness | ❌ Ad-hoc | ✅ Pinned to REPO_ROOT |
| Failure evidence | ❌ Summarized | ✅ Quoted verbatim |

**Real-world consequences**:
- 🚨 A cached PASS hides a real regression.
- 🚨 An unrun race detector ships a data race to production.
- 🚨 `./...` from a subdirectory tests a fraction of the module and reports green.

## §0.7 Anti-Patterns: Go command pitfalls
❌ **`-run` treated as an exact name**
```bash
go test -run TestParse ./...    # ALSO runs TestParseAll, TestParseHeader...
```
✅ Anchor the regex: `go test -run '^TestParse$' ./...`

❌ **Trusting `gofmt -l`'s exit code**
```bash
gofmt -l . && echo "clean"     # prints "clean" even with unformatted files
```
✅ `test -z "$(gofmt -l .)"` — gate on empty output.

❌ **Benchmarks that also run the tests**
```bash
go test -bench=. ./...          # runs every test too
```
✅ `go test -bench=. -run='^$' ./...`

❌ **Assuming a cached result is a fresh run**
```bash
go test ./...                   # "(cached)" is not a new run
```
✅ `go test -count=1 ./...` whenever inputs, env, or deps changed.

## §0.8 Path Conventions (read first)
See `@.ai/contexts/path-conventions.md`. Go commands take **package patterns**,
not paths — always `cd "$REPO_ROOT"` before using `./...`.

## §1 Routing & Classification
**User intent → Guide section mapping**:

| User Intent | Interpret As | Jump to Guide Section |
| --- | --- | --- |
| "Build the project" | Compile everything | `@.ai/contexts/build-and-test-guide.md` → **§3** |
| "Run the tests" | Full suite | `@.ai/contexts/build-and-test-guide.md` → **§4.1** |
| "Only rerun TestParse" | Targeted run | `@.ai/contexts/build-and-test-guide.md` → **§4.2** |
| "Is it flaky?" / "concurrency bug" | Race + stress | `@.ai/contexts/build-and-test-guide.md` → **§4.3** |
| "Coverage" | Coverage profile | `@.ai/contexts/build-and-test-guide.md` → **§5.1** |
| "How fast is it?" | Benchmarks | `@.ai/contexts/build-and-test-guide.md` → **§5.2** |
| "Build for linux/arm" | Cross-compilation | `@.ai/contexts/build-and-test-guide.md` → **§6** |
| "Go version? environment?" | Setup validation | `@.ai/contexts/build-and-test-guide.md` → **§2** |
| "It fails/hangs" | Troubleshooting | `@.ai/contexts/build-and-test-guide.md` → **§7** |

## §1.5 Quick Decision Tree (for AI routing)
1. IF request is build/compile → load §2 + §3.
2. ELSE IF request is the full suite → load §2 + §4.1.
3. ELSE IF request is a targeted test → load §4.2 (anchor the `-run` regex).
4. ELSE IF request mentions race/flaky/concurrency → load §4.3 (`-race` mandatory).
5. ELSE IF request is coverage → load §5.1.
6. ELSE IF request is benchmarks → load §5.2 (`-run='^$'` mandatory).
7. ELSE IF request is cross-compilation/release → load §6.
8. ELSE IF failure report → load §7.
9. ELSE → ask a clarifying question.

## §2 Load Strategy
**Authoritative references**:
- Primary guide → `@.ai/contexts/build-and-test-guide.md`
- Supporting files → `@go.mod`, `@.ai/contexts/dependency-map.md`

**On-demand load map**:
- Go version / directive → `go.mod` first three lines
- Dependency resolution failures → dependency-map §4
- Verification wording → build guide §9

## §3 Execution Protocol
**Pre-flight validation (mandatory)**:
- Run **§2 Setup Checklist** from `@.ai/contexts/build-and-test-guide.md`.
- `cd "$(git rev-parse --show-toplevel)"` before any `./...` pattern.
- Record `go version` and the `go` directive from `go.mod`; report a mismatch
  before building.

**Workflow steps**:
1. Classify the request using §1.
2. Load the matching guide section.
3. Execute in order: `go build ./...` → `go vet ./...` → `go test ...`.
4. Capture checkpoints (exit codes, pass/fail counts, failing test names).
5. If any checkpoint fails, jump to the troubleshooting matrix (guide §7).

**Checkpoints**:
- Build: `go build ./...` exits 0 with no output.
- Vet: `go vet ./...` exits 0 with no output.
- Test: exit code + pass/fail counts + the full output of each failing test.
- Race (when concurrency was touched): `go test -race` exits 0.

**Reporting rule**: quote failing test output verbatim. Never write "some tests
failed" — name them and show the assertion.

## §4 Delegation & Handoffs
**When to invoke other SKILLs**:

| Scenario | Delegate To | Invocation |
| --- | --- | --- |
| Architecture/package context needed | `project-navigator` | "Use project-navigator to locate the package" |
| Formatting or lint failures | `code-quality` | "Use code-quality to format the tree" |
| Commit/push after a green run | `vcs-workflow-manager` | "Help me commit using vcs-workflow-manager" |
| Test failures needing a code review | `code-reviewer` | "Use code-reviewer for a local review" |

## §5 Troubleshooting
### §5.1 Common Failures
| Failure Mode | Symptoms | Root Cause | Recovery Steps |
| --- | --- | --- | --- |
| Toolchain missing | `go: command not found` | Go not installed | Report and STOP; do not simulate a build |
| Version too old | `go.mod requires go >= X` | Toolchain older than the directive | Report the mismatch; ask before lowering the directive |
| No packages matched | `matched no packages` | cwd outside the module | `cd "$REPO_ROOT"` and rerun |
| Stale PASS | Passes but behavior is wrong | Test result cache | `go test -count=1 ./...` |
| Missing checksum | `missing go.sum entry` | Import added without tidy | `go mod tidy`, then rebuild |
| Test timeout | `panic: test timed out` | Deadlock or blocking I/O | `go test -timeout 30s`; read the goroutine dump |
| Data race | `WARNING: DATA RACE` | Unsynchronized shared state | Report both stacks; fix the sharing — never drop `-race` |
| Import cycle | `import cycle not allowed` | Bidirectional dependency | Delegate to `project-navigator`; extract the shared type |
| Network blocked | `dial tcp: i/o timeout` | Offline / proxy | `GOFLAGS=-mod=mod GOPROXY=off` with a warm module cache |
| cgo failure | `gcc: command not found` | cgo without a C toolchain | `CGO_ENABLED=0` if no cgo is needed |

### §5.2 Degraded Mode Operations
| Missing Tool | Impact | Fallback Strategy |
| --- | --- | --- |
| `go` | Cannot build or test | Provide the exact commands; request installation; do NOT claim a build result |
| `golangci-lint` | Reduced static analysis | Fall back to `go vet`; state the reduced coverage |
| `benchstat` | Cannot compare benchmarks | Report raw before/after numbers and say the comparison is unnormalized |

## §6 Self-Assessment Checklist
- [ ] Request classified with guide section references
- [ ] Required guide sections loaded and cited
- [ ] Pre-flight validation completed (`go version` vs `go.mod`)
- [ ] cwd pinned to REPO_ROOT before any `./...`
- [ ] Commands executed with stdout/stderr and exit codes captured
- [ ] `-race` used when concurrency was touched
- [ ] `-count=1` used when a cached result would mislead
- [ ] Failing tests named and their output quoted verbatim
- [ ] Next steps provided to user
