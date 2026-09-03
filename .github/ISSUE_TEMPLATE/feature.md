---
name: Feature
about: Propose a new user-visible capability
title: "<package>: <capability in imperative form>"
labels: enhancement
---

## Problem
<What cannot be done today, and why that matters. Describe the problem, not the solution.>

## Proposed solution
<What the capability should do, from the caller's point of view.>

## Proposed API (if applicable)
```go
// Sketch of the exported surface.
```

## Alternatives considered
<Other approaches and why they were not chosen. "None" is an acceptable answer only if it is true.>

## Scope
**In scope**
- <item>

**Out of scope**
- <item>

## Dependencies
<New modules required, if any, with justification per @.ai/contexts/dependency-map.md §3. Prefer the standard library.>

## Acceptance criteria
- [ ] <observable behavior 1>
- [ ] Exported identifiers documented per code-style-guide §5.4
- [ ] Tests cover both the happy path and error paths
- [ ] `gofmt` / `go vet` / `go test -race ./...` pass
