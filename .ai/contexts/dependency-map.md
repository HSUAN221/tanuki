# tanuki: Dependency Map

## §0. Quick Start

Dependencies are declared in `go.mod` and pinned in `go.sum`. **Never state a
dependency or version from memory — always query.**

### §0.1 Load Strategy for AI Agents
- Dependency version question → run §1 query, quote the output.
- "Can I add X?" → §3 Policy.
- Build fails on a module → §4 Troubleshooting.

---

## §1. Query Commands

### §1.1 Dependency queries

```bash
REPO_ROOT=$(git rev-parse --show-toplevel); cd "$REPO_ROOT"

# Module path and Go version
head -3 go.mod

# All direct requirements
go list -m -f '{{if not .Indirect}}{{.Path}} {{.Version}}{{end}}' all

# Full module graph (direct + indirect)
go list -m all

# Why is module X in the build?
go mod why <module-path>

# Which packages depend on X?
go list -deps -f '{{.ImportPath}} {{.Imports}}' ./... | grep <module-path>

# Available updates
go list -m -u all

# Known vulnerabilities (if govulncheck is installed)
govulncheck ./...
```

**Degraded mode**: if the `go` toolchain is unavailable, read `go.mod` directly
with `cat go.mod` and say explicitly that indirect resolution could not be
verified.

---

## §2. Dependencies

### §2.1 Standard library (always available)
No `require` entry. Prefer the standard library over a third-party module
whenever it can do the job — `net/http`, `encoding/json`, `log/slog`,
`context`, `errors`, `testing`.

### §2.2 Direct requirements (REQUIRED)
Listed in the first `require` block of `go.mod`. Query with §1; do not
transcribe them here — this table would go stale.

### §2.3 Indirect requirements
Marked `// indirect` in `go.mod`. They are managed by `go mod tidy`; never edit
them by hand.

### §2.4 Test-only dependencies
A module imported solely from `_test.go` files is still a direct requirement in
Go. Keep test helpers in the standard library where possible.

### §2.5 Tool dependencies
Developer tools (`goimports`, `golangci-lint`, `govulncheck`) are **not**
module dependencies. Install them separately; do not add them to `go.mod`
unless the repository adopts a `tools.go` pattern.

---

## §3. Dependency Policy

| Rule | Rationale |
| --- | --- |
| Standard library first | Zero supply-chain and version-drift cost |
| Every new direct `require` needs a justification in the PR body | Keeps the surface auditable |
| Pin exact versions; never use `latest` in committed state | Reproducible builds |
| `go mod tidy` before every commit that touches imports | Keeps `go.mod`/`go.sum` honest |
| Commit `go.sum` alongside `go.mod`, always in the same commit | A split leaves the tree unbuildable |
| No `replace` directives on `main` | `replace` is a local-development tool |
| Vendoring disabled unless the whole team opts in | Avoid a large, noisy `vendor/` diff |

---

## §4. Troubleshooting

| Symptom | Root cause | Fix |
| --- | --- | --- |
| `missing go.sum entry` | Dependency added without tidy | `go mod tidy` |
| `checksum mismatch` | `go.sum` conflict or tampering | `go clean -modcache && go mod download`; investigate if it persists |
| `module ... found, but does not contain package` | Wrong import path | Verify with `go list -m -versions <module>` |
| `ambiguous import` | Two modules provide the same path | `go mod why` on both; drop one |
| `updates to go.mod needed` in CI | `go mod tidy` not run | Run it locally and commit the result |
| Unexpected indirect bump | Transitive upgrade | `go mod why -m <module>` to find the requester |
