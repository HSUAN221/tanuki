# tanuki: Build & Test Guide

## §0. Load Strategy for AI Agents

### §0.1 Section overview

| Section | Purpose |
| --- | --- |
| §1 Decision Flow | Route a request to the right section |
| §2 Setup Checklist | Mandatory pre-flight validation |
| §3 Build Workflow | Daily golden path |
| §4 Test Workflow | `go test` in all its shapes |
| §5 Coverage & Benchmarks | Measurement flows |
| §6 Cross-Compilation & Release Builds | `GOOS`/`GOARCH`, ldflags |
| §7 Troubleshooting Matrix | Failure → recovery |
| §8 Command Templates | Copy bank |
| §9 Verification Checklist | Post-run confirmation |

### §0.2 Load strategy
Load §2 always. Then load only the one section §1 routes you to. Do not read
the whole guide for a single `go test` invocation.

---

## §1 Decision Flow

```
Request
 ├─ "build" / "compile" / "does it compile"      → §2 + §3
 ├─ "run the tests" / "test everything"          → §2 + §4.1
 ├─ "test this package" / "just TestFoo"         → §2 + §4.2
 ├─ "race" / "flaky" / "concurrency bug"         → §2 + §4.3
 ├─ "coverage"                                   → §5.1
 ├─ "benchmark" / "how fast"                     → §5.2
 ├─ "build for linux/windows/arm"                → §6
 ├─ "it fails / hangs / weird error"             → §7
 └─ unclear                                      → ask a clarifying question
```

---

## §2 Setup Checklist (mandatory pre-flight)

```bash
REPO_ROOT=$(git rev-parse --show-toplevel) && cd "$REPO_ROOT" || exit 1

command -v go >/dev/null || { echo "STOP: go toolchain not on PATH"; exit 1; }
go version                       # record in the report
grep '^go ' go.mod               # required language version
go env GOMODCACHE GOCACHE        # confirm caches are writable
```

**Stop conditions**:
- `go` is not on PATH → do **not** guess. Report the missing toolchain, provide
  the commands the user would run, and stop.
- Installed Go is older than the `go` directive in `go.mod` → report the
  mismatch before building.
- cwd is outside the module → `./...` silently under-matches; always `cd "$REPO_ROOT"`.

---

## §3 Build Workflow (daily golden path)

```bash
cd "$REPO_ROOT"
go mod download          # 1. fetch dependencies
go build ./...           # 2. compile every package
go vet ./...             # 3. static analysis (MANDATORY, not optional)
```

**Build a specific binary**:
```bash
go build -o bin/tanuki ./cmd/tanuki
```

**Checkpoints**:
- `go build ./...` exits 0 and prints nothing.
- `go vet ./...` exits 0 and prints nothing.
- If a binary was requested, it exists: `ls -l bin/`.

**`bin/` is not committed** — confirm it is covered by `.gitignore` before
creating it.

---

## §4 Test Workflow

### §4.1 Full suite
```bash
cd "$REPO_ROOT"
go test ./...                    # cached, quiet
go test -count=1 ./...           # force re-run, bypass the test cache
go test -v ./...                 # verbose, per-test output
```

Use `-count=1` whenever a previous run's cached PASS would be misleading (after
changing testdata, environment, or a dependency).

### §4.2 Targeted runs
```bash
go test ./internal/store/                       # one package
go test -run '^TestParse$' ./internal/store/    # one test (anchored regex)
go test -run 'TestParse/empty_input' ./...      # one subtest
go test -v -run '^TestParse$' ./internal/store/ # with output
```

`-run` takes a **regex**. Anchor it with `^...$`, or `TestParseAll` will also
match `-run TestParse`.

### §4.3 Race detector and stress
```bash
go test -race ./...                     # data race detection
go test -race -count=20 -run '^TestX$' ./pkg/...   # flakiness hunt
go test -timeout 60s ./...              # default is 10m; shorten to catch hangs
```

Run `-race` before any PR that touches goroutines, channels, or shared state.

### §4.4 Build-tagged tests
```bash
go test -tags=integration ./...
```

---

## §5 Coverage & Benchmarks

### §5.1 Coverage
```bash
go test -coverprofile=coverage.out ./...
go tool cover -func=coverage.out            # per-function summary
go tool cover -func=coverage.out | tail -1  # total
go tool cover -html=coverage.out -o coverage.html
```
`coverage.out` and `coverage.*` are already ignored by `.gitignore`.

### §5.2 Benchmarks
```bash
go test -bench=. -benchmem -run='^$' ./...        # benchmarks only, no tests
go test -bench='^BenchmarkParse$' -benchtime=10x ./internal/store/
```
`-run='^$'` is what prevents the normal tests from running alongside.

---

## §6 Cross-Compilation & Release Builds

```bash
# Cross-compile (no cgo)
CGO_ENABLED=0 GOOS=linux   GOARCH=amd64 go build -o bin/tanuki-linux-amd64  ./cmd/tanuki
CGO_ENABLED=0 GOOS=darwin  GOARCH=arm64 go build -o bin/tanuki-darwin-arm64 ./cmd/tanuki
CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -o bin/tanuki.exe          ./cmd/tanuki

# Stripped release build with version stamping
VERSION=$(git describe --tags --always --dirty)
go build -trimpath -ldflags "-s -w -X main.version=$VERSION" -o bin/tanuki ./cmd/tanuki

# List every supported platform
go tool dist list
```

---

## §7 Troubleshooting Matrix

| Failure mode | Symptom | Root cause | Recovery |
| --- | --- | --- | --- |
| Toolchain missing | `go: command not found` | Go not installed / not on PATH | Report and stop; do not simulate a build |
| Version too old | `go.mod requires go >= X` | Toolchain older than the directive | Upgrade Go or lower the directive deliberately |
| Missing checksum | `missing go.sum entry` | Import added without tidy | `go mod tidy` |
| No packages | `matched no packages` | cwd outside the module | `cd "$REPO_ROOT"` |
| Stale PASS | Tests pass but behavior is wrong | Test result cache | `go test -count=1 ./...` |
| Test timeout | `panic: test timed out after 10m` | Deadlock or blocking I/O | `go test -timeout 30s` and read the goroutine dump |
| Data race | `WARNING: DATA RACE` | Unsynchronized shared state | Fix the sharing; never silence `-race` |
| Import cycle | `import cycle not allowed` | Bidirectional dependency | Extract the shared type downward |
| Cache permission | `permission denied` under `GOCACHE` | Read-only or foreign-owned cache | `go env -w GOCACHE=...` to a writable path |
| Network blocked | `dial tcp: i/o timeout` on proxy | Offline environment | `GOFLAGS=-mod=mod GOPROXY=off go build ./...` with a warm module cache |
| cgo failure | `gcc: command not found` | cgo enabled without a C toolchain | `CGO_ENABLED=0` if no cgo is needed |

---

## §8 Command Templates (copy bank)

```bash
# Full local gate — run this before every push
cd "$(git rev-parse --show-toplevel)" \
  && gofmt -l . \
  && go vet ./... \
  && go test -race -count=1 ./...

# Clean everything and rebuild
go clean -cache -testcache && go build ./...

# Show what a package exports
go doc ./internal/store

# Show effective build environment
go env
```

---

## §9 Verification Checklist (post-run)

- [ ] `go version` recorded and compatible with `go.mod`
- [ ] `go build ./...` exited 0
- [ ] `go vet ./...` exited 0
- [ ] `go test ./...` exited 0; pass/fail counts captured
- [ ] `-race` run performed if concurrency was touched
- [ ] Failing test names and full output quoted verbatim (never summarized away)
- [ ] Generated artifacts (`bin/`, `coverage.out`) confirmed git-ignored
