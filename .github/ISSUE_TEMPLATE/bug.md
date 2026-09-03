---
name: Bug
about: Report incorrect, reproducible behavior
title: "<package>: <short description of the wrong behavior>"
labels: bug
---

## Summary
<One or two sentences: what is wrong.>

## Reproduction
Minimal steps or a minimal Go program that reproduces the problem.

```go
// minimal reproducer
```

```bash
# commands
```

## Expected behavior
<What should happen.>

## Actual behavior
<What happens instead. Paste the exact output, error, or panic — do not paraphrase.>

```
<output>
```

## Environment
- Go: `<go version>`
- Commit: `<git rev-parse --short HEAD>`
- Branch: `<branch>`
- Platform: `<GOOS>/<GOARCH>`

## Impact
<Who is affected, how often, and whether a workaround exists.>

## Suspected cause (optional)
<`file:line` and reasoning, if known.>

## Acceptance criteria
- [ ] A test reproduces the bug and fails before the fix
- [ ] The test passes after the fix
- [ ] `go test -race ./...` passes
