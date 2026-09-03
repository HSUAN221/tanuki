# tanuki: Issue Workflow Guide

## §0 Purpose
Define how issues are created, routed, updated, and closed in the tanuki
repository, so that an agentic AI assistant and a human developer produce
issues of the same shape.

Issue writes are remote writes: they follow the confirmation gate in
`@.ai/contexts/vcs-workflow-guide.md` §4.1 and are executed through the
`vcs-workflow-manager` skill.

---

## §1 Issue Templates

Templates live in `.github/ISSUE_TEMPLATE/`.

| Template | File | Use for |
| --- | --- | --- |
| Bug | `bug.md` | Something behaves incorrectly and is reproducible |
| Feature | `feature.md` | New user-visible capability |
| Task | `task.md` | Scoped engineering work with a known solution |
| Spike | `spike.md` | Time-boxed investigation with an unknown answer |

### §1.1 Template selection triggers

| Signal in the request | Template |
| --- | --- |
| "crash", "panic", "wrong result", "regression", "fails when" | Bug |
| "add", "support", "it should be able to", "new command" | Feature |
| "refactor", "upgrade", "migrate", "add CI step", "document" | Task |
| "investigate", "evaluate", "compare", "figure out whether" | Spike |
| Ambiguous | Ask one clarifying question; default to Task |

**Rule**: read the selected template file and fill in **every** section. Do not
invent sections, and do not silently drop one — write "N/A — <reason>" instead.
Strip the YAML front matter before posting the body.

---

## §2 Agentic Intake

Before drafting, gather from the conversation and the repository:

| Field | Source | If missing |
| --- | --- | --- |
| Title | User request | Draft one; confirm with the user |
| Reproduction | User; verify locally if cheap | Ask — a bug without repro steps is not actionable |
| Expected vs actual | User | Ask |
| Environment | `go version`, `git rev-parse --short HEAD`, `go env GOOS GOARCH` | Query, do not guess |
| Affected package | `git diff` / `rg` | Query |
| Severity | §3 routing table | Propose; let the user override |
| Labels | §3 | Propose |

```bash
# Environment block for the issue body
{
  echo "- Go: $(go version 2>/dev/null || echo 'not installed')"
  echo "- Commit: $(git rev-parse --short HEAD)"
  echo "- Branch: $(git branch --show-current)"
  echo "- Platform: $(go env GOOS 2>/dev/null)/$(go env GOARCH 2>/dev/null)"
} > /tmp/issue-env.md
```

**Draft → preview → confirm → create → verify.** Never create an issue from a
first draft without showing it.

---

## §3 Routing Rules

### §3.1 Labels

| Label | Meaning |
| --- | --- |
| `bug` | Incorrect behavior |
| `enhancement` | New capability |
| `task` | Scoped engineering work |
| `spike` | Investigation |
| `documentation` | Docs only |
| `priority:critical` | Data loss, security, or production down |
| `priority:high` | Blocks work; no workaround |
| `priority:medium` | Has a workaround |
| `priority:low` | Nice to have |
| `good first issue` | Small, well-scoped, low context needed |
| `blocked` | Waiting on something external |

### §3.2 Severity → priority

| Impact | Priority |
| --- | --- |
| Data loss, security, panic on a normal path | `priority:critical` |
| Feature unusable, no workaround | `priority:high` |
| Degraded but workaroundable | `priority:medium` |
| Cosmetic, docs, cleanup | `priority:low` |

### §3.3 Branch naming from an issue
An issue numbered `#42` titled "store entries never expire" becomes branch
`fix/42-store-entries-never-expire` (VCS §1.1).

---

## §4 Progress Updates

Post a progress comment when: the investigation conclusion changes, the scope
changes, the issue becomes blocked, or a PR is opened against it.

```markdown
**Status**: investigating | in progress | blocked | in review

**Findings**
- <what is now known, with `file:line` or command output>

**Next**
- <the next concrete step>

**Blocked by**: <#id or external dependency, if applicable>
```

Post via `vcs-workflow-manager` (VCS §3.4), using `--body-file`.

---

## §5 Completion Checklist

Before closing an issue:
- [ ] The fix or change is merged into `main`
- [ ] A regression test exists (for bugs) and fails without the fix
- [ ] `gofmt` / `go vet` / `go test -race` all pass on `main`
- [ ] Docs updated if behavior changed
- [ ] The closing PR references the issue (`Closes: #<id>`)
- [ ] A closing comment states what changed and links the PR

```bash
gh issue close <n> --comment "Fixed in #<pr>. <one-line summary of the change>."
gh issue view <n> --json state,closedAt     # verify
```

Do not close an issue whose fix is only on a feature branch.
