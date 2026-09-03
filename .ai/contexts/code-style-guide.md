# tanuki: Code Style & Formatting Guide (Agentic AI)

## §0 Load Strategy for AI Agents

Load §3.0 (pre-flight) always. Then load only the section §9.3 routes you to.
Never load §10 (audit) for a plain format request.

### §0.1 Section index (on-demand loading)

| Section | Purpose |
| --- | --- |
| §1 | Quick start — daily commands |
| §2 | Scope & usage |
| §3 | Agentic workflows (format / validate / lint / docs) |
| §4 | Safety & verification |
| §5 | Language rules & conventions |
| §6 | Templates (copy-ready) |
| §7 | Troubleshooting |
| §8 | Tooling & references |
| §9 | Agentic AI API reference |
| §10 | Code audit (comprehensive analysis) |

---

## §1 Quick Start (daily use)

### §1.1 Daily workflows (most common)

```bash
REPO_ROOT=$(git rev-parse --show-toplevel); cd "$REPO_ROOT"

gofmt -l .                 # list unformatted files (empty output = clean)
gofmt -w internal/store/store.go   # format one file in place
goimports -w .             # format + fix import grouping (preferred if installed)
go vet ./...               # static analysis
golangci-lint run          # aggregate linters (if .golangci.yml exists)
```

### §1.2 Common scenarios

| Scenario | Command |
| --- | --- |
| "Is my tree formatted?" | `gofmt -l .` |
| "Format everything" | `gofmt -w .` (or `goimports -w .`) |
| "Format only what I staged" | see §3.2 |
| "CI-style check, change nothing" | `test -z "$(gofmt -l .)"` |
| "Show me what would change" | `gofmt -d <file>` |
| "Simplify redundant code" | `gofmt -s -d .` |

---

## §2 Scope & usage

**In scope**: `.go` source files, `go.mod`, and Go doc comments.
**Out of scope**: Markdown, YAML, and shell scripts — those follow their own
tools and are not governed by this guide.

**Authority order** when guidance conflicts:
1. `gofmt` output (mechanical, non-negotiable)
2. This guide
3. Effective Go / Go Code Review Comments conventions
4. Personal preference (lowest)

---

## §3 Agentic workflows

### §3.0 Pre-flight validation (mandatory)

Run before **any** formatting, linting, or audit workflow:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel) && cd "$REPO_ROOT" || exit 1

command -v gofmt >/dev/null || echo "WARN: gofmt missing (ships with Go)"
command -v goimports >/dev/null || echo "INFO: goimports missing; gofmt only"
command -v golangci-lint >/dev/null || echo "INFO: golangci-lint missing; go vet only"
git status --porcelain           # record the pre-existing dirty state
```

**Stop conditions**:
- No Go toolchain → report the gap and provide commands; do not hand-format.
- Working tree already dirty in files you are about to rewrite → surface it, so
  the user can tell your changes apart from theirs.
- Target file does not exist or is not `.go` → stop and say so.

### §3.1 Format a single file

```bash
gofmt -d <file>      # 1. preview the diff — show it to the user
gofmt -s -w <file>   # 2. apply, including simplifications
goimports -w <file>  # 3. fix import grouping, if goimports is installed
gofmt -l <file>      # 4. verify — must print nothing
```

Confirmation gate: step 2 writes to disk. Preview first for anything beyond a
file the user explicitly named.

### §3.2 Format staged files (pre-commit)

```bash
FILES=$(git diff --cached --name-only --diff-filter=ACM -- '*.go')
[ -z "$FILES" ] && echo "no staged Go files" && exit 0
echo "$FILES" | xargs gofmt -s -w
echo "$FILES" | xargs -r goimports -w
echo "$FILES" | xargs git add          # re-stage the formatted content
git diff --cached --stat
```

Re-staging matters: formatting after `git add` leaves the formatted version out
of the commit unless you `git add` again.

### §3.3 Validate without modifying (CI / review)

```bash
UNFORMATTED=$(gofmt -l .)
if [ -n "$UNFORMATTED" ]; then
  echo "FAIL: unformatted files:"; echo "$UNFORMATTED"; exit 1
fi
go vet ./... || exit 1
command -v golangci-lint >/dev/null && golangci-lint run
```

Exit code 1 with the file list is the contract; do not auto-fix in this mode.

### §3.4 Bulk format a directory tree

```bash
gofmt -l ./internal          # 1. show the blast radius FIRST
# 2. require explicit user confirmation, quoting the file count
gofmt -s -w ./internal
goimports -w ./internal
git diff --stat              # 3. verify the change is formatting-only
```

Stop condition: if `git diff` shows semantic changes rather than whitespace and
import moves, revert and investigate.

### §3.5 Doc comment remediation

Find exported identifiers missing a doc comment:

```bash
# golangci-lint with revive/stylecheck is the reliable detector
golangci-lint run --enable=revive,stylecheck

# Quick heuristic scan when golangci-lint is unavailable
rg -n '^(func|type|var|const) [A-Z]' --type go
```

Fix by writing a comment that **starts with the identifier name** — see §5.4
and the templates in §6.

### §3.6 Lint remediation

```bash
golangci-lint run                    # report
golangci-lint run --fix              # auto-fixable rules only
golangci-lint run ./internal/store/  # scope down
```

Never blanket-disable a linter. If a finding is genuinely wrong, add a narrow
`//nolint:<linter> // <reason>` on the specific line, with the reason.

---

## §4 Safety & verification

### §4.1 Pre-flight checks
Per §3.0. Additionally, record `git rev-parse HEAD` so a rollback point exists.

### §4.2 Post-format verification

```bash
gofmt -l .                  # must be empty
go build ./...              # must still compile
go test ./...               # must still pass
git diff --stat             # scope should match what was announced
```

A formatting workflow that breaks the build has failed, no matter how clean the
output looks.

### §4.3 Rollback procedures

```bash
git checkout -- <file>          # discard changes to one unstaged file
git restore --staged <file>     # unstage but keep the edit
git stash                       # park everything
git reset --hard <sha>          # DESTRUCTIVE — explicit confirmation required
```

---

## §5 Language rules & conventions

### §5.1 Formatting (mandatory)

| Rule | Enforced by |
| --- | --- |
| Tabs for indentation, spaces for alignment | `gofmt` |
| No manual line-length limit; break for readability | judgment |
| Imports in three groups: stdlib / third-party / local, separated by blank lines | `goimports` |
| No unused imports or variables | compiler |
| One statement per line | `gofmt` |

Never hand-format. If `gofmt` and a human disagree, `gofmt` wins.

### §5.2 Naming conventions

| Element | Convention | Example |
| --- | --- | --- |
| Package | short, lowercase, no underscores, no plurals | `store`, not `Stores` or `store_util` |
| Exported identifier | `MixedCaps` | `ParseConfig` |
| Unexported identifier | `mixedCaps` | `parseConfig` |
| Initialisms | consistent case | `URL`, `ID`, `HTTPServer`, `userID` |
| Interface (single method) | method name + `-er` | `Reader`, `Formatter` |
| Errors (sentinel) | `Err` prefix | `ErrNotFound` |
| Error types | `Error` suffix | `ValidationError` |
| Test | `TestXxx`, subtests via `t.Run("case name", ...)` | `TestParse` |
| Receiver | 1–2 letters, consistent across all methods | `func (s *Store) Get(...)` |

**Anti-stutter**: `store.New`, not `store.NewStore`; `http.Server`, not
`http.HTTPServer`.

### §5.3 Idiomatic Go (recommended)

- **Errors**: wrap with `fmt.Errorf("reading config: %w", err)`; check with
  `errors.Is`/`errors.As`. Never `_ = err`. Never `panic` in library code.
- **Context**: `ctx context.Context` is always the first parameter; never store
  a context in a struct field.
- **Zero values**: design types so the zero value is usable (`var buf bytes.Buffer`).
- **Slices**: preallocate with `make([]T, 0, n)` when `n` is known.
- **defer**: use it for cleanup; be aware it runs at *function* exit, not block exit.
- **Goroutines**: whoever starts one must define how it stops. Never leak.
- **Interfaces**: define them where they are consumed, keep them small, accept
  interfaces and return concrete structs.
- **Concurrency**: prefer channels for handoff and `sync.Mutex` for state; run
  `go test -race` on anything concurrent.
- **Struct tags**: keep JSON/DB tags on one line and consistently ordered.

### §5.4 Doc comment rules (mandatory for exported identifiers)

1. Every exported identifier has a doc comment.
2. The comment **begins with the identifier name**.
3. It is a complete sentence ending in a period.
4. Every package has one package comment, on one file only, formatted
   `// Package <name> ...`.
5. Deprecations use a `// Deprecated: <replacement>.` paragraph.

```go
// ParseConfig reads the configuration at path and returns the parsed Config.
// It returns ErrNotFound if the file does not exist.
func ParseConfig(path string) (*Config, error) { ... }
```

### §5.5 Test conventions

- Table-driven tests with a `map[string]struct{...}` or slice of named cases.
- Use `t.Run(name, ...)` for subtests so `-run` can target them.
- `t.Helper()` in every assertion helper.
- `t.Cleanup(...)` instead of manual teardown.
- `t.Parallel()` where tests are independent; capture the loop variable if the
  Go version predates 1.22.
- Fixtures live in `testdata/`; golden files are regenerated behind a
  `-update` flag, never edited by hand.

---

## §6 Templates (copy-ready)

### §6.1 Package comment
```go
// Package store provides persistence primitives for tanuki.
//
// The zero value of Store is not usable; construct one with New.
package store
```

### §6.2 Exported type
```go
// Store persists records to the underlying backend.
// A Store is safe for concurrent use by multiple goroutines.
type Store struct {
	mu   sync.Mutex
	data map[string][]byte
}
```

### §6.3 Constructor
```go
// New returns a Store backed by an in-memory map.
func New() *Store {
	return &Store{data: make(map[string][]byte)}
}
```

### §6.4 Function with context and wrapped error
```go
// Get returns the record stored under key.
// It returns ErrNotFound if no such record exists.
func (s *Store) Get(ctx context.Context, key string) ([]byte, error) {
	if err := ctx.Err(); err != nil {
		return nil, fmt.Errorf("store.Get %q: %w", key, err)
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	v, ok := s.data[key]
	if !ok {
		return nil, fmt.Errorf("store.Get %q: %w", key, ErrNotFound)
	}
	return v, nil
}
```

### §6.5 Sentinel error
```go
// ErrNotFound is returned when a requested record does not exist.
var ErrNotFound = errors.New("not found")
```

### §6.6 Table-driven test
```go
func TestParse(t *testing.T) {
	t.Parallel()

	tests := map[string]struct {
		input   string
		want    Config
		wantErr error
	}{
		"empty input":   {input: "", wantErr: ErrEmpty},
		"single field":  {input: "a=1", want: Config{A: 1}},
	}

	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			t.Parallel()
			got, err := Parse(tc.input)
			if !errors.Is(err, tc.wantErr) {
				t.Fatalf("Parse(%q) err = %v, want %v", tc.input, err, tc.wantErr)
			}
			if err == nil && got != tc.want {
				t.Errorf("Parse(%q) = %+v, want %+v", tc.input, got, tc.want)
			}
		})
	}
}
```

---

## §7 Troubleshooting

### §7.1 gofmt parse failure
`<file>:12:5: expected ';', found '}'` — the file does not compile. `gofmt`
cannot format invalid syntax. Fix the syntax error first.

### §7.2 goimports removes an import you need
It is only used under a build tag, or in code the parser cannot see. Add the
tag to the invocation, or keep the import with a `_` blank identifier if it is
for side effects.

### §7.3 Import grouping keeps flipping
Two contributors run `gofmt` (2 groups) and `goimports` (3 groups). Standardize
on `goimports` and note the module prefix with `-local github.com/HSUAN221/tanuki`.

### §7.4 golangci-lint version mismatch
Different versions enable different default linters. Pin the version in
`.golangci.yml` and in CI; report the version in every lint result.

### §7.5 `//nolint` has no effect
It must be on the same line as the finding (or directly above the block), and
must name the linter: `//nolint:errcheck // best-effort close on read path`.

---

## §8 Tooling & references

| Tool | Role | Install |
| --- | --- | --- |
| `gofmt` | Canonical formatter | ships with Go |
| `goimports` | Formatter + import management | `go install golang.org/x/tools/cmd/goimports@latest` |
| `go vet` | Correctness analyzers | ships with Go |
| `golangci-lint` | Linter aggregator | https://golangci-lint.run/ |
| `govulncheck` | Vulnerability scan | `go install golang.org/x/vuln/cmd/govulncheck@latest` |
| `go doc` | Render doc comments | ships with Go |

External conventions: *Effective Go*, *Go Code Review Comments*, and the
standard library itself as the reference implementation of this style.

---

## §9 Agentic AI API reference

### §9.1 Invocation patterns

| Intent | Command |
| --- | --- |
| format file | `gofmt -s -w <file> && goimports -w <file>` |
| format staged | §3.2 script |
| validate | `test -z "$(gofmt -l .)" && go vet ./...` |
| lint | `golangci-lint run` |
| audit | §10 |

### §9.2 Expected exit codes

| Command | 0 | non-zero |
| --- | --- | --- |
| `gofmt -l .` | always 0 — **check stdout, not the exit code** | only on I/O error |
| `go vet ./...` | clean | findings or build failure |
| `golangci-lint run` | clean | findings |
| `go test ./...` | all pass | any failure |

⚠️ `gofmt -l` exits 0 even when files are unformatted. Gate on empty output:
`test -z "$(gofmt -l .)"`.

### §9.3 Decision tree (routing)

```
Request
 ├─ query only ("what's the rule for X") → §5/§6, no execution
 ├─ "format" + file        → §3.0 + §3.1
 ├─ "format" + staged      → §3.0 + §3.2
 ├─ "format" + directory   → §3.0 + §3.4 (confirmation required)
 ├─ "check" / "validate"   → §3.0 + §3.3 (read-only)
 ├─ "lint"                 → §3.0 + §3.6
 ├─ "docs" / "comments"    → §3.0 + §3.5 + §6
 ├─ "audit"                → §3.0 + §3.3 + §10
 ├─ "fix"                  → §3.0 + §10 → plan → confirm → apply → re-audit
 └─ unclear                → clarify using §9.1
```

---

## §10 Code Audit (comprehensive analysis)

### §10.1 Audit scope
A single file, or a small set of files. For a whole branch or PR, delegate to
the `code-reviewer` skill instead.

### §10.2 Correctness checklist
- [ ] Every returned `error` is checked, and wrapped with `%w` where it crosses
      a package boundary
- [ ] No `panic` outside `main` / genuinely unrecoverable initialization
- [ ] Nil pointer and nil map writes impossible on every path
- [ ] Slice indexing bounded; no `s[i:j]` with unvalidated `i`, `j`
- [ ] Integer conversions cannot silently truncate
- [ ] `defer` inside a loop is deliberate, not an accidental resource leak

### §10.3 Concurrency checklist
- [ ] Every goroutine has a defined termination path
- [ ] Shared state is mutex-protected or channel-owned
- [ ] `context` cancellation is honored in every blocking operation
- [ ] No `WaitGroup.Add` inside the goroutine it counts
- [ ] Channels have a clear owner responsible for closing
- [ ] `go test -race` passes

### §10.4 Resource checklist
- [ ] Every `Open`/`Dial`/`NewRequest` has a matching `defer Close()`
- [ ] HTTP response bodies are drained and closed
- [ ] Timeouts set on all network operations; no unbounded blocking
- [ ] `sync.Pool` / buffer reuse where the allocation profile justifies it

### §10.5 API & idiom checklist
- [ ] Exported surface is minimal and documented (§5.4)
- [ ] Interfaces defined at the consumer, small, and not over-abstracted
- [ ] Zero value usable, or construction enforced by an unexported field
- [ ] `context.Context` first parameter on blocking calls
- [ ] No global mutable state
- [ ] Naming follows §5.2, no stutter

### §10.6 Performance checklist
- [ ] No unnecessary allocation in hot paths (`strings.Builder` over `+=`)
- [ ] Slices/maps preallocated when the size is known
- [ ] Large structs passed by pointer, small ones by value
- [ ] No O(n²) where a map lookup would do
- [ ] Claims backed by a benchmark, not intuition

### §10.7 Test checklist
- [ ] New behavior has a test
- [ ] Error paths are tested, not just the happy path
- [ ] Table-driven with named subtests
- [ ] No sleeps used for synchronization

### §10.8 Risk levels

| Level | Meaning | Examples |
| --- | --- | --- |
| 🔴 Critical | Data loss, race, panic, security | Unchecked type assertion on user input; data race |
| 🟡 Major | Wrong behavior in a plausible case | Unwrapped error losing context; leaked goroutine |
| 🟢 Minor | Style, docs, clarity | Missing doc comment; stuttering name |

### §10.9 Audit output format

```
### 📄 File: <path>

**Scope**: <lines / functions reviewed>
**Tooling**: gofmt <status> · go vet <status> · golangci-lint <status/version>

#### 🔴 Critical (N)
- `<file>:<line>` — <finding>. **Impact**: <consequence>. **Fix**: <action>.

#### 🟡 Major (N)
- `<file>:<line>` — <finding>. **Fix**: <action>.

#### 🟢 Minor (N)
- `<file>:<line>` — <finding>.

**Verdict**: ✅ APPROVE | 🟡 NEEDS WORK | 🔴 BLOCK
```

Every finding cites `file:line`. A finding without a location is not a finding.
