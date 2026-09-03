# Path Handling Guide for AI Agents

Comprehensive path resolution strategies for document references and shell
command execution in the tanuki repository.

---

## §1 Document Reference Paths

All `@...` shortcuts are repo-root-relative (per `@.ai/contexts/project-overview.md`).

### §1.1 For skill-relative environments

If your tool resolves paths relative to the *skill* directory
(`.claude/skills/<name>/`), prepend `../../../` before the path.
- Example: `@.ai/contexts/vcs-workflow-guide.md` → `@../../../.ai/contexts/vcs-workflow-guide.md`

### §1.2 For agent-file-relative environments

If your tool resolves paths relative to the agent instruction file
(`.claude/CLAUDE.md`, `.codex/AGENTS.md`, ...), prepend `../`.
- Example: `@.ai/contexts/project-overview.md` → `../.ai/contexts/project-overview.md`

### §1.3 Detection

```bash
# Test how your environment resolves relative paths
if [ -f ".ai/contexts/project-overview.md" ]; then
    echo "Repo-relative - use @ paths directly"
elif [ -f "../.ai/contexts/project-overview.md" ]; then
    echo "Agent-file-relative - prepend ../"
elif [ -f "../../../.ai/contexts/project-overview.md" ]; then
    echo "Skill-relative - prepend ../../../"
fi
```

---

## §2 Shell Command Execution Paths

### §2.1 Problem

Shell commands resolve relative paths against the **current working directory
(cwd)**. Unlike document references, shell processes do not understand `@...`
shortcuts.

**Failure scenario**:
```bash
cd internal/core/
./scripts/sync-ai-config.sh
# ❌ no such file or directory
```

### §2.2 Solution: REPO_ROOT pattern

**Set repo root at workflow start**:
```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
```

**Use in commands**:
```bash
"$REPO_ROOT/scripts/sync-ai-config.sh"
go test "$REPO_ROOT/..."
```

### §2.3 When to use REPO_ROOT

| Script type | Needs REPO_ROOT? | Example |
| --- | --- | --- |
| System tools | ❌ No (on PATH) | `go`, `gofmt`, `git`, `gh` |
| Project scripts | ✅ Yes (repo-specific) | `scripts/sync-ai-config.sh` |
| Config files | ⚠️ Optional (if explicit) | `.golangci.yml` |

### §2.4 Go-specific note

Go commands are **package-pattern** based, not path based. Prefer
`go test ./...` executed from the repo root over path juggling. If the cwd is a
subdirectory, `./...` silently narrows the scope — always `cd "$REPO_ROOT"`
first, or pass an explicit module-root pattern.

### §2.5 Best practices

1. **Set once per workflow**: define `REPO_ROOT` in pre-flight checks.
2. **Quote the variable**: `"$REPO_ROOT/..."` to survive spaces.
3. **State the assumption**: if a workflow assumes repo-root cwd, say so.

---

## §3 Quick Reference

| Path type | Context | Pattern | Example |
| --- | --- | --- | --- |
| Document reference | AI reads guide | `@...` or `../` prefix | `@.ai/contexts/vcs-workflow-guide.md` |
| Package pattern | Go tool | `./...` from repo root | `go vet ./...` |
| Project script | Shell executes | `"$REPO_ROOT/..."` | `"$REPO_ROOT/scripts/sync-ai-config.sh"` |
| System tool | Shell executes | Direct command | `gofmt -l .` |

---

**See also**:
- `@.ai/contexts/code-style-guide.md` §3.0 for pre-flight integration
- `@.ai/contexts/build-and-test-guide.md` for Go build path handling
