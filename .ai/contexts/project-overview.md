# tanuki: Project Overview

## §0 Quick Lookup

| Need | Load |
| --- | --- |
| Project identity and ownership | §1 Identity |
| Mission and supported scope | §2 Mission |
| Build, runtime, and test stack | §3 Tech Stack |
| Constraints for implementation | §4 Key Constraints |

## §1 Identity
| Field | Details |
| --- | --- |
| Name | tanuki |
| Version | Query via `git describe --tags --always` (fallback: `git rev-parse --short HEAD`) |
| Type | Go module |
| Language | Go (query exact version via `grep '^go ' go.mod`) |
| Repository | https://github.com/HSUAN221/tanuki |
| Forge | GitHub (`gh` CLI) |
| License | MIT (see `LICENSE`) |
| Default branch | `main` |

## §2 Mission
Provide a small, dependency-light Go codebase with a reproducible build/test
story and a documented agentic workflow, so that both human developers and
agentic AI assistants operate under the same policies.

## §3 Tech Stack
| Aspect | Details |
| --- | --- |
| Build system | Go toolchain (`go build`, `go install`); module mode |
| Testing | `go test` with the standard `testing` package |
| Formatting | `gofmt` (mandatory), `goimports` (import grouping) |
| Static analysis | `go vet` (mandatory), `golangci-lint` (when configured) |
| Dependencies | `go.mod` / `go.sum`; vendoring disabled by default |
| VCS host | GitHub; pull requests (PR), issues, GitHub Actions |

## §4 Key Constraints
- Module-mode Go only; do not reintroduce `GOPATH` layouts.
- `gofmt` clean is non-negotiable; unformatted code must never be committed.
- `go vet ./...` must pass before any push.
- Keep the dependency surface minimal; every new `require` in `go.mod` needs a
  stated justification in the PR description.
- All version/dependency facts must be queried from `go.mod` / `git`, never
  recalled from memory.
- Exported identifiers require doc comments starting with the identifier name.
