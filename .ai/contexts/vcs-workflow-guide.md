# tanuki: VCS Workflow Guide

## 0. Document Structure & Navigation Guide

### 0.0 Who should use this guide
- **Agentic AI assistants** executing Git/GitHub operations on behalf of a user.
- **Automation scripts** that must follow repository policy.
- **Human developers** who want the canonical commands.

### 0.1 How to use this guide
Do **not** read this document end-to-end. Use §0.4 to jump to the section that
matches the intent, and load only that section plus §4 (Safety Protocol).

### 0.2 Section overview

| Section | Purpose |
| --- | --- |
| §1 | Core concepts: branches, commit format, collaboration policy |
| §2 | Workflow decision matrix (intent → workflow) |
| §3 | Common workflows (commit, PR, review response, issues, hotfix) |
| §4 | Safety protocol (confirmation gates, prerequisites) |
| §5 | Troubleshooting |
| §6 | Advanced topics (releases, auth, large repos) |
| §7 | GitHub API & data extraction |
| §8 | Quick reference cards |
| §9 | Command reference (read-only vs write) |

### 0.3 Load Strategy for AI Agents
1. Always run §3.0 context gathering first.
2. Load the one §3.x workflow that matches the intent.
3. Load §4 before any write operation. This is not optional.
4. Load §5 only on failure.

### 0.4 Quick navigation map

| Intent | Go to |
| --- | --- |
| "commit my changes" | §3.1 |
| "push" | §3.1 step 6 |
| "create a PR" | §3.2 |
| "post a review comment on a PR" | §3.3.1 |
| "post an inline / line-level comment" | §3.3.2 |
| "respond to reviewer feedback" | §3.3 |
| "create / update an issue" | §3.4 |
| "hotfix production" | §3.5 |
| "check CI" | §9.3 |
| "which branch?" | §1.1 |
| "extract PR/issue data" | §3.6, §7 |

---

## 1. Core Concepts

### 1.1 Branch strategy

`main` is the only long-lived branch. It is always releasable.

| Branch type | Pattern | Base | Merges into |
| --- | --- | --- | --- |
| Feature | `feat/<issue-id>-<slug>` | `main` | `main` |
| Fix | `fix/<issue-id>-<slug>` | `main` | `main` |
| Refactor | `refactor/<slug>` | `main` | `main` |
| Docs | `docs/<slug>` | `main` | `main` |
| Chore/CI | `chore/<slug>` | `main` | `main` |
| Hotfix | `hotfix/<slug>` | `main` (or the release tag) | `main` |

**Rules**:
- Never commit directly to `main`. Every change lands via a pull request (PR).
- Slugs are lowercase, hyphen-separated, ASCII: `feat/12-add-store-cache`.
- Branch from an up-to-date `main`: `git fetch origin && git switch -c <name> origin/main`.
- Delete the branch after merge.

**Validate a branch name**:
```bash
BRANCH=$(git branch --show-current)
echo "$BRANCH" | grep -Eq '^(feat|fix|refactor|docs|chore|hotfix|test|perf)/[a-z0-9._-]+$' \
  && echo "OK: $BRANCH" || echo "POLICY VIOLATION: $BRANCH"
```

### 1.2 Commit message standards

Conventional Commits:

```
<type>(<scope>): <subject>

<body — what and why, wrapped at 72 columns>

Refs: #<issue>
```

| Field | Rule |
| --- | --- |
| `type` | `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert` |
| `scope` | Optional; the package or area (`store`, `cmd`, `ci`) |
| `subject` | Imperative mood, lowercase, no trailing period, ≤ 72 chars |
| `body` | Optional but expected for anything non-trivial; explain *why* |
| footer | `Refs: #<id>` to link, `Closes: #<id>` to auto-close, `BREAKING CHANGE: ...` |

**Good**:
```
feat(store): add TTL-based cache eviction

The in-memory store grew unbounded under sustained write load. Entries now
carry an expiry and are swept on read, which keeps the working set bounded
without a background goroutine.

Refs: #42
```

**Bad**: `fix stuff`, `Update code.`, `WIP`, `fix: Fixed the bug.`

**Validate a message**:
```bash
head -1 "$MSG_FILE" | grep -Eq '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9._-]+\))?!?: .{1,72}$' \
  && echo OK || echo "POLICY VIOLATION: subject line"
```

### 1.3 Collaboration policies
- One logical change per commit; one coherent concern per PR.
- Rebase your branch onto `main`; do not merge `main` into a feature branch.
- Never force-push a branch someone else is reviewing without saying so;
  use `--force-with-lease`, never bare `--force`.
- Never rewrite published history on `main`.
- Secrets never enter a commit. If one does, rotate the credential first, then
  purge the history — purging alone is not remediation.
- Generated artifacts (`bin/`, `coverage.*`) stay out of commits.

---

## 2. Workflow Decision Matrix

### 2.1 Intent → workflow mapping

| Intent keywords | Workflow | Section |
| --- | --- | --- |
| commit, stage, save changes | Commit | §3.1 |
| push, upload | Push (part of commit flow) | §3.1 |
| PR, pull request, merge request, MR | Create PR | §3.2 |
| review comment, feedback, note | Respond to feedback | §3.3 |
| inline, line-level, 行內留言, 區塊留言 | Inline comment | §3.3.2 |
| issue, ticket, bug report | Issue workflow | §3.4 |
| hotfix, production down | Emergency hotfix | §3.5 |
| CI, pipeline, actions, checks | CI status | §9.3 |
| list, show, info, number | Data extraction | §3.6, §7 |

### 2.2 Execution mode selection

| Mode | When | Behavior |
| --- | --- | --- |
| Read-only | Query, status, list | Execute directly, no confirmation |
| Local write | Stage, commit, local branch | Preview, then execute |
| Remote write | Push, PR, issue, comment, label | **Explicit confirmation required** |
| Destructive | Force-push, hard reset, branch delete, history rewrite | **Explicit confirmation + stated blast radius** |

### 2.3 CLI vs API

| Task | Preferred | Why |
| --- | --- | --- |
| Everyday PR/issue operations | `gh` CLI | Handles auth and pagination |
| Structured data extraction | `gh api ... \| jq` | Machine-readable |
| Inline review comments | `gh api` with an explicit body | The CLI's positional support is thin |
| Anything `gh` cannot do | `gh api` REST/GraphQL | Full surface |

### 2.4 Automation decision flow (agentic AI)

```
Request
 ├─ Read-only?          → execute → report
 ├─ Local write?        → preview → execute → verify
 ├─ Remote write?       → preview → CONFIRM → execute → read back and verify
 └─ Destructive?        → state blast radius → CONFIRM → execute → verify
```

A remote write is not complete until it has been **read back**. HTTP 200 is not
verification.

---

## 3. Common Workflows

### 3.0 Context gathering (prerequisite for ALL workflows)

Run this first, every time. Do not ask the user questions that these commands
already answer.

```bash
REPO_ROOT=$(git rev-parse --show-toplevel) && cd "$REPO_ROOT" || exit 1

git remote -v                          # remote URL → host and owner/repo
git branch --show-current              # current branch
git status -sb                         # dirty state + ahead/behind
git log --oneline -5                   # recent history
git fetch origin --quiet && git status -sb   # true ahead/behind vs remote

# Derive owner/repo from the remote (works for SSH and HTTPS)
REPO_SLUG=$(git remote get-url origin | sed -E 's#^[a-z+]+://##; s#^[^@]+@##; s#^[^/:]+[:/]##; s#\.git$##')
echo "repo: $REPO_SLUG"

# GitHub CLI availability and auth
command -v gh >/dev/null && gh auth status || echo "INFO: gh unavailable — git-only mode"

# Open PR for the current branch, if any
gh pr view --json number,title,state,url 2>/dev/null || echo "no PR for this branch"
```

**Record**: repo slug, branch, dirty state, ahead/behind, PR number, issue id
extracted from the branch name (`feat/42-...` → `#42`).

**Stop conditions**:
- Detached HEAD → stop, report, ask which branch to use.
- Current branch is `main` and the request is a write → stop; §1.1 forbids it.
- `gh` unavailable and the request needs it → §5.3 degraded mode.

### 3.1 Complete commit workflow

```bash
# 1. Pre-flight (§4.2) — branch policy
BRANCH=$(git branch --show-current)
[ "$BRANCH" = "main" ] && { echo "STOP: cannot commit directly to main"; exit 1; }

# 2. Review what will be committed
git status -sb
git diff                  # unstaged
git diff --cached         # staged

# 3. Quality gate — MUST pass before committing
gofmt -l . | tee /dev/stderr | grep -q . && { echo "STOP: unformatted files"; exit 1; }
go vet ./... || exit 1
go test ./... || exit 1

# 4. Stage deliberately — prefer explicit paths over -A
git add internal/store/store.go internal/store/store_test.go
git status --short

# 5. Commit with a policy-compliant message (§1.2)
#    Use a file to avoid shell interpretation of backticks and quotes.
cat > /tmp/commit-msg.txt <<'MSG'
feat(store): add TTL-based cache eviction

Entries now carry an expiry and are swept on read, bounding memory under
sustained write load.

Refs: #42
MSG
git commit -F /tmp/commit-msg.txt

# 6. Verify locally BEFORE any remote write
git log -1 --stat
git status -sb

# 7. Push — REMOTE WRITE, requires explicit user confirmation
git push -u origin "$BRANCH"

# 8. Verify
git status -sb            # expect: up to date with origin/<branch>
```

**Stop conditions**: unformatted files, failing `go vet`, failing tests,
branch is `main`, or the message fails §1.2 validation.

**Never** use `git add -A` without first showing the user the full
`git status --short` and getting agreement — it is how secrets and build
artifacts get committed.

### 3.2 Create a pull request

```bash
# Prerequisites: branch pushed, quality gate green, issue id known
BRANCH=$(git branch --show-current)
git push -u origin "$BRANCH"

# Draft the body in a file — never inline with -b "..."
cat > /tmp/pr-body.md <<'BODY'
## Summary
<what changed and why, 2-4 sentences>

## Changes
- <change 1>
- <change 2>

## Validation
- `gofmt -l .` — clean
- `go vet ./...` — pass
- `go test -race -count=1 ./...` — pass (N tests)

## Risk
<blast radius, rollback plan, or "low: additive only">

Refs: #42
BODY

# REMOTE WRITE — confirm with the user first, showing the rendered body
gh pr create \
  --base main \
  --head "$BRANCH" \
  --title "feat(store): add TTL-based cache eviction" \
  --body-file /tmp/pr-body.md

# Verify by reading back
gh pr view --json number,title,url,state,body
```

**Draft PRs**: add `--draft` when the work is incomplete.
**Update an existing PR body**: `gh pr edit <number> --body-file /tmp/pr-body.md`.

### 3.3 Respond to PR feedback

```bash
PR=$(gh pr view --json number -q .number)

# Read all review threads, unresolved first
gh api "repos/$REPO_SLUG/pulls/$PR/comments" --paginate \
  | jq -r '.[] | "\(.path):\(.line // .original_line) [\(.user.login)] \(.body)"'

# Read summary-level reviews
gh api "repos/$REPO_SLUG/pulls/$PR/reviews" --paginate \
  | jq -r '.[] | "[\(.state)] \(.user.login): \(.body)"'

# Read issue-style comments on the PR
gh pr view "$PR" --comments
```

Then: address the feedback in code → §3.1 commit workflow → reply on each
thread with what changed and the commit SHA.

#### 3.3.1 Post a summary comment (safe Markdown handling)

**Problem**: passing Markdown inline via `-b "..."` lets the shell interpret
backticks as command substitution — this both corrupts the comment and executes
whatever was inside the backticks.

```bash
# 1. Write to a file (heredoc with a QUOTED delimiter disables expansion)
cat > /tmp/pr-note.md <<'NOTE'
## Review Summary

`go test -race ./...` passes. Two findings:

- 🟡 `internal/store/store.go:42` — error is dropped on the read path.
- 🟢 `internal/store/store.go:88` — exported `Sweep` is missing a doc comment.
NOTE

# 2. Preview to the user and CONFIRM before posting
cat /tmp/pr-note.md

# 3. Post — REMOTE WRITE
gh pr comment "$PR" --body-file /tmp/pr-note.md

# 4. Read back and verify the content survived intact
gh api "repos/$REPO_SLUG/issues/$PR/comments" \
  | jq -r '.[-1] | "\(.html_url)\n---\n\(.body)"'
```

**Verification is mandatory**: compare the read-back body against the file.
If backticks or non-ASCII text are mangled, delete the comment and repost.

#### 3.3.2 Post a line-level (inline) review comment

Inline comments anchor to a file and line **in the PR diff**. A line that is
not part of the diff cannot be commented on inline — the API rejects it, or
silently degrades it to a plain comment.

```bash
PR=<number>
REPO_SLUG=$(git remote get-url origin | sed -E 's#^[a-z+]+://##; s#^[^@]+@##; s#^[^/:]+[:/]##; s#\.git$##')

# 1. Get the head SHA of the PR — the comment must reference this exact commit
COMMIT_ID=$(gh api "repos/$REPO_SLUG/pulls/$PR" -q .head.sha)
echo "head sha: $COMMIT_ID"

# 2. Confirm the target line is actually in the diff
gh api "repos/$REPO_SLUG/pulls/$PR/files" --paginate \
  | jq -r '.[] | "\(.filename)\n\(.patch)"' | less
# STOP if the file or line is not present in any patch hunk.

# 3. Build the payload in a JSON file (avoids all shell quoting hazards)
cat > /tmp/inline.json <<'JSON'
{
  "body": "This error is dropped; wrap it with %w so callers can use errors.Is.",
  "commit_id": "COMMIT_ID_PLACEHOLDER",
  "path": "internal/store/store.go",
  "line": 42,
  "side": "RIGHT"
}
JSON
sed -i "s/COMMIT_ID_PLACEHOLDER/$COMMIT_ID/" /tmp/inline.json

# 4. Preview + CONFIRM with the user, then post
gh api --method POST "repos/$REPO_SLUG/pulls/$PR/comments" --input /tmp/inline.json > /tmp/inline-result.json

# 5. VERIFY — require a real anchored comment, not merely HTTP 200
jq -r 'if .path and .line then "OK anchored: \(.path):\(.line)\n\(.html_url)"
       else "FAIL: not anchored — \(.)" end' /tmp/inline-result.json
```

**Field reference**:

| Field | Meaning | Notes |
| --- | --- | --- |
| `commit_id` | PR head SHA | Must be current; a stale SHA fails or misplaces the comment |
| `path` | Repo-relative file path | Must appear in `pulls/<n>/files` |
| `line` | Line number in the **new** file | Use with `side: RIGHT` |
| `side` | `RIGHT` (added/context) or `LEFT` (removed) | Deleted lines need `LEFT` |
| `start_line` + `start_side` | Multi-line range start | `line` is the end of the range |
| `in_reply_to` | Existing comment id | Replies into an existing thread |

**Multi-line range**:
```json
{ "body": "...", "commit_id": "...", "path": "internal/store/store.go",
  "start_line": 40, "start_side": "RIGHT", "line": 46, "side": "RIGHT" }
```

**Batch several findings as one review** (preferred over N separate comments —
it sends one notification instead of N):
```bash
cat > /tmp/review.json <<'JSON'
{
  "commit_id": "COMMIT_ID_PLACEHOLDER",
  "body": "Two blocking findings, one nit.",
  "event": "COMMENT",
  "comments": [
    {"path": "internal/store/store.go", "line": 42, "side": "RIGHT", "body": "Dropped error."},
    {"path": "internal/store/store.go", "line": 88, "side": "RIGHT", "body": "Missing doc comment."}
  ]
}
JSON
sed -i "s/COMMIT_ID_PLACEHOLDER/$COMMIT_ID/" /tmp/review.json
gh api --method POST "repos/$REPO_SLUG/pulls/$PR/reviews" --input /tmp/review.json | jq -r .html_url
```

`event` is one of `COMMENT`, `APPROVE`, `REQUEST_CHANGES`. An agent must
**never** send `APPROVE` or `REQUEST_CHANGES` without explicit user instruction
— those carry review authority.

**Reply into an existing thread**:
```bash
gh api --method POST "repos/$REPO_SLUG/pulls/$PR/comments/$COMMENT_ID/replies" \
  -f body="Fixed in $(git rev-parse --short HEAD)."
```

### 3.4 Create or update issue work

```bash
# List templates available in this repository
ls .github/ISSUE_TEMPLATE/

# Draft the body from the chosen template — see @.ai/contexts/issue-workflow-guide.md
cp .github/ISSUE_TEMPLATE/bug.md /tmp/issue-body.md
# ...fill in every section; delete the YAML front matter before posting...

# Preview + CONFIRM, then create — REMOTE WRITE
gh issue create --title "store: entries never expire under write load" \
                --body-file /tmp/issue-body.md \
                --label bug

# Verify
gh issue view <number> --json number,title,state,labels,url

# Update
gh issue edit <number> --add-label "priority:high" --add-assignee @me
gh issue comment <number> --body-file /tmp/progress.md
gh issue close <number> --comment "Fixed in #43."
```

Read `@.ai/contexts/issue-workflow-guide.md` before drafting — it defines
template selection and required sections.

### 3.5 Emergency hotfix

```bash
git fetch origin
git switch -c hotfix/<slug> origin/main

# Minimal fix + a regression test that fails without it
gofmt -l . && go vet ./... && go test -race ./...

git commit -F /tmp/commit-msg.txt     # type must be `fix`
git push -u origin hotfix/<slug>

gh pr create --base main --title "fix: <subject>" --body-file /tmp/pr-body.md --label hotfix
```

Even under pressure: no direct commit to `main`, no skipped tests. Speed comes
from a small diff, not from skipping the gate.

### 3.6 Data extraction (API-assisted)

```bash
# PRs
gh pr list --state open --json number,title,author,headRefName,createdAt
gh pr view <n> --json number,title,body,state,mergeable,reviewDecision,files
gh pr diff <n>
gh pr checks <n>

# Issues
gh issue list --state open --json number,title,labels,assignees
gh issue view <n> --json number,title,body,state,labels,comments

# Raw API with jq
gh api "repos/$REPO_SLUG/pulls?state=open&per_page=100" --paginate \
  | jq -r '.[] | "#\(.number) \(.title) [\(.user.login)]"'
```

### 3.7 Common manual shortcuts (human developers)

```bash
git switch -c feat/42-add-cache origin/main   # start work
git commit --amend --no-edit                  # fix the last commit (unpushed only)
git rebase -i origin/main                     # tidy history before opening a PR
git push --force-with-lease                   # after a rebase, on YOUR branch only
gh pr checkout <n>                            # review someone else's PR locally
```

---

## 4. Safety Protocol

### 4.1 Confirmation requirements

| Operation | Confirmation | Must state |
| --- | --- | --- |
| `git status`, `log`, `diff`, `gh ... view/list` | None | — |
| `git add`, `git commit` | Preview the diff | Files and message |
| `git push` | ✅ Explicit | Branch, remote, commit count |
| `gh pr create` / `comment` / `review` | ✅ Explicit | Full rendered body |
| `gh issue create` / `edit` / `close` | ✅ Explicit | Full body and labels |
| `git push --force-with-lease` | ✅ Explicit | What history is being replaced |
| `git reset --hard`, `git clean -fd` | ✅ Explicit | Exactly what will be lost |
| Branch deletion | ✅ Explicit | Whether it is merged |
| Anything touching `main` directly | 🚫 Refuse | Cite §1.1 |

### 4.2 Prerequisite checklist

Before **any** write:
- [ ] §3.0 context gathering completed
- [ ] Branch name passes §1.1 validation, and is not `main`
- [ ] Working tree state understood (`git status -sb`)
- [ ] Branch is current with `origin/main` (or the divergence is intentional)
- [ ] `gofmt -l .` is empty
- [ ] `go vet ./...` passes
- [ ] `go test ./...` passes
- [ ] Commit message passes §1.2 validation
- [ ] No secrets, credentials, or generated artifacts in the diff
- [ ] `gh auth status` is authenticated (for GitHub writes)

### 4.3 Automated execution loop (agents/scripts)

```
for each step:
    1. QUERY   — read current state
    2. DECIDE  — confirm the step is still applicable
    3. PREVIEW — show the exact command and expected effect
    4. GATE    — if remote/destructive: stop for explicit confirmation
    5. ACT     — execute, capture stdout AND stderr AND exit code
    6. VERIFY  — read back; a non-zero exit or a mismatched read-back is a STOP
    7. REPORT  — state what happened, quoting real output
```

Never report success from an unverified step. Never summarize an error away.

### 4.4 Manual execution guidance (human developers)
The same gates apply, but you are your own confirmation. The one rule that
never bends: `--force-with-lease`, never `--force`.

### 4.5 Common safeguards
- Prefer `git restore` / `git switch` over overloaded `git checkout`.
- `--force-with-lease` refuses to clobber a remote you have not seen; bare
  `--force` does not. Use the former, always.
- Scan the staged diff for secrets before committing:
  `git diff --cached | grep -inE '(api[_-]?key|secret|token|password|BEGIN .*PRIVATE KEY)'`
- Write comment and PR bodies to files; never inline Markdown with backticks.
- Set `GH_PAGER=cat` in scripted contexts so `gh` does not block on a pager.

---

## 5. Troubleshooting

### 5.1 Diagnostic decision tree

```
Failure
 ├─ exit code 128, "not a git repository"     → cd to REPO_ROOT
 ├─ "! [rejected]" on push                    → §5.2 non-fast-forward
 ├─ "CONFLICT"                                → §5.2 merge conflict
 ├─ HTTP 401 / "gh auth"                      → §5.3 auth
 ├─ HTTP 404 on a repo that exists            → §5.3 wrong slug or no scope
 ├─ HTTP 422 on an inline comment             → §5.3 invalid diff position
 ├─ command hangs                             → pager; set GH_PAGER=cat
 └─ else                                      → capture full stderr, report, stop
```

### 5.2 Git errors

| Symptom | Root cause | Recovery |
| --- | --- | --- |
| `! [rejected] ... non-fast-forward` | Branch behind remote | `git fetch origin && git rebase origin/<branch>` |
| `CONFLICT (content)` | Overlapping edits | Resolve, `git add`, `git rebase --continue` |
| `error: Your local changes would be overwritten` | Dirty tree | `git stash` → operate → `git stash pop` |
| `detached HEAD` | Checked out a SHA | `git switch -c <branch>` to keep the work |
| `nothing to commit` | Nothing staged | `git status`; stage explicitly |
| `refusing to merge unrelated histories` | Wrong base | Verify the base branch; do not pass `--allow-unrelated-histories` reflexively |
| Committed a secret | Policy breach | **Rotate the credential first**, then purge history, then force-push with the team informed |
| Lost commits after a reset | Reflog still has them | `git reflog` → `git reset --hard <sha>` |

### 5.3 GitHub errors

| Symptom | Root cause | Recovery |
| --- | --- | --- |
| `gh: command not found` | CLI not installed | Degraded mode: git-only. Report the gap; provide the commands the user can run. |
| HTTP 401 | Token expired | `gh auth login`; verify with `gh auth status` |
| HTTP 403 rate limit | Too many requests | `gh api rate_limit`; back off; use `--paginate` instead of a loop |
| HTTP 404 on an existing repo | Wrong slug, or token lacks `repo` scope | Re-derive the slug per §3.0; `gh auth refresh -s repo` |
| HTTP 422 `pull_request_review_thread.line ... invalid` | Target line is not in the diff | Re-read `pulls/<n>/files`; pick a line inside a hunk (§3.3.2) |
| HTTP 422 on `commit_id` | Stale head SHA | Re-fetch `.head.sha`; the PR was pushed to since |
| Inline comment appears as a plain comment | Position payload was invalid | Read back and require `.path` and `.line` to be non-null (§3.3.2 step 5) |
| Comment body mangled | Backticks interpreted by the shell | Repost via `--body-file`; verify by read-back |
| Non-ASCII text garbled | Locale mismatch | Ensure a UTF-8 locale (`LC_ALL=C.UTF-8` or `zh_TW.UTF-8`) before posting |
| `gh` hangs with no output | Interactive pager | `export GH_PAGER=cat` |

### 5.4 Network / rate-limit issues
```bash
gh api rate_limit | jq '.resources.core'
git config --get http.proxy; echo "$HTTPS_PROXY"
```
On a transient failure, retry once after a short pause. On a second failure,
stop and report — do not loop.

### 5.5 Quick fixes (human developers)
```bash
git commit --amend                 # fix the last message (unpushed only)
git restore --staged <file>        # unstage
git restore <file>                 # discard unstaged edits (DESTRUCTIVE)
git reflog                         # find anything "lost"
git rebase --abort                 # back out of a bad rebase
```

---

## 6. Advanced Topics

### 6.1 Release management

```bash
# Tag an annotated release from main
git switch main && git pull
git tag -a v0.2.0 -m "v0.2.0"
git push origin v0.2.0             # REMOTE WRITE — confirm

# Generate release notes from merged PRs
gh release create v0.2.0 --generate-notes

# Version stamping in a build (see build-and-test-guide §6)
go build -ldflags "-X main.version=$(git describe --tags --always)" ./cmd/tanuki
```

Semantic versioning: `MAJOR` for breaking API changes, `MINOR` for additive
features, `PATCH` for fixes. Below `v1.0.0`, breaking changes go in `MINOR`.

### 6.2 Repository setup & authentication

```bash
# Validate the remote
git remote -v
# Expect: git@github.com:HSUAN221/tanuki.git

# Derive the slug rather than hard-coding it
REPO_SLUG=$(git remote get-url origin | sed -E 's#^[a-z+]+://##; s#^[^@]+@##; s#^[^/:]+[:/]##; s#\.git$##')

# Authenticate
gh auth login                      # interactive — the USER runs this, not the agent
gh auth status                     # verify scopes: repo, read:org
gh auth refresh -s repo            # add a missing scope

# Identity for commits
git config user.name; git config user.email
```

An agent must never run an interactive login. Ask the user to run `gh auth
login` themselves and report back.

### 6.3 Performance tips for large repositories
```bash
git clone --filter=blob:none <url>   # blobless clone
git fetch --depth=50 origin main     # shallow fetch
gh api ... --paginate                # let gh handle pagination
git maintenance start                # background gc
```

### 6.4 Common anti-patterns (organizational)

| Anti-pattern | Why it hurts | Instead |
| --- | --- | --- |
| `git add -A` reflexively | Commits secrets and artifacts | Stage explicit paths |
| `git push --force` | Destroys others' work | `--force-with-lease` |
| Committing directly to `main` | No review, no CI gate | Branch + PR |
| `-m "fix"` | Unsearchable history | §1.2 format |
| Merging `main` into a feature branch repeatedly | Tangled history | Rebase |
| Approving your own PR via an agent | Bypasses review | Never auto-approve |
| Inline Markdown in `-b "..."` | Shell mangles backticks | `--body-file` |

---

## 7. GitHub API & Data Extraction

### 7.1 Endpoint reference

| Purpose | Endpoint |
| --- | --- |
| PR detail | `GET repos/{slug}/pulls/{n}` |
| PR changed files | `GET repos/{slug}/pulls/{n}/files` |
| PR review comments (inline) | `GET|POST repos/{slug}/pulls/{n}/comments` |
| Reply to a review comment | `POST repos/{slug}/pulls/{n}/comments/{id}/replies` |
| PR reviews (batched) | `GET|POST repos/{slug}/pulls/{n}/reviews` |
| PR/issue comments (summary) | `GET|POST repos/{slug}/issues/{n}/comments` |
| Issues | `GET|POST repos/{slug}/issues` |
| Check runs | `GET repos/{slug}/commits/{sha}/check-runs` |
| Workflow runs | `GET repos/{slug}/actions/runs` |
| Rate limit | `GET rate_limit` |

Note: a PR **is** an issue for the comment API — summary comments go to
`/issues/{n}/comments`, inline comments to `/pulls/{n}/comments`.

### 7.2 JSON parsing strategies

```bash
# Unresolved review threads (GraphQL — REST does not expose resolution state)
gh api graphql -f query='
  query($owner:String!, $repo:String!, $pr:Int!) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$pr) {
        reviewThreads(first:100) {
          nodes { isResolved path line comments(first:1){nodes{author{login} body}} }
        }
      }
    }
  }' -F owner="${REPO_SLUG%%/*}" -F repo="${REPO_SLUG##*/}" -F pr="$PR" \
  | jq -r '.data.repository.pullRequest.reviewThreads.nodes[]
           | select(.isResolved | not)
           | "\(.path):\(.line) [\(.comments.nodes[0].author.login)] \(.comments.nodes[0].body)"'

# Failing checks only
gh pr checks "$PR" --json name,state,link | jq -r '.[] | select(.state!="SUCCESS") | "\(.state) \(.name) \(.link)"'
```

⚠️ `select(.resolved == false)` misses records where the field is **absent**.
Use `select((.resolved // false) == false)` when working with REST payloads.

### 7.3 Batch operations best practices
- Use `--paginate`; do not hand-roll a page loop.
- Prefer one batched review (§3.3.2) over N individual comments.
- Check `gh api rate_limit` before a large fan-out.
- Cache read results in a temp file rather than re-querying.

---

## 8. Quick Reference Cards

### 8.1 Git cheat sheet

```bash
git status -sb                         # state + tracking
git switch -c feat/42-x origin/main    # new branch from fresh main
git add <paths>                        # stage explicitly
git commit -F /tmp/msg.txt             # commit from a file
git fetch origin && git rebase origin/main
git push -u origin "$(git branch --show-current)"
git push --force-with-lease            # after a rebase, your branch only
git log --oneline --graph -20
git diff origin/main...HEAD            # everything your branch adds
git reflog                             # the undo history
```

### 8.2 gh cheat sheet

```bash
gh auth status
gh pr create --base main --title "..." --body-file /tmp/pr-body.md
gh pr view --json number,title,state,reviewDecision,url
gh pr diff <n>
gh pr checks <n>
gh pr comment <n> --body-file /tmp/note.md
gh pr review <n> --comment --body-file /tmp/review.md   # never --approve unattended
gh issue create --title "..." --body-file /tmp/issue.md --label bug
gh issue list --state open --json number,title,labels
gh api "repos/$REPO_SLUG/pulls/<n>/files" --paginate
gh run list --limit 10
gh run view <run-id> --log-failed
```

### 8.3 One-liners

```bash
# Full pre-push gate
gofmt -l . && go vet ./... && go test -race -count=1 ./...

# What does my branch actually change?
git diff --stat origin/main...HEAD

# Issue number from the branch name
git branch --show-current | grep -oE '[0-9]+' | head -1

# Repo slug from the remote
git remote get-url origin | sed -E 's#^[a-z+]+://##; s#^[^@]+@##; s#^[^/:]+[:/]##; s#\.git$##'
```

### 8.4 Error code quick lookup

| Code | Meaning | Section |
| --- | --- | --- |
| git 128 | Not a repo / bad ref | §5.2 |
| git 1 on push | Rejected | §5.2 |
| HTTP 401 | Unauthenticated | §5.3 |
| HTTP 403 | Forbidden / rate limited | §5.3, §5.4 |
| HTTP 404 | Wrong slug or missing scope | §5.3 |
| HTTP 422 | Invalid payload (usually diff position) | §5.3 |

---

## 9. Command Reference

### 9.1 Git (read-only) — no confirmation needed
`git status`, `git log`, `git diff`, `git show`, `git branch --show-current`,
`git remote -v`, `git fetch`, `git reflog`, `git rev-parse`, `git describe`

### 9.2 Git (write) — preview; confirm before anything remote
`git add`, `git commit`, `git switch -c`, `git rebase`, `git stash`,
`git push`, `git tag`, `git reset`, `git restore`, `git clean`

### 9.3 GitHub (read-only)
```bash
gh pr list / view / diff / checks
gh issue list / view
gh run list / view
gh api <GET endpoint>
gh api rate_limit
```

**CI status**:
```bash
gh pr checks "$PR"                       # per-check status for a PR
gh run list --branch "$(git branch --show-current)" --limit 5
gh run view <run-id> --log-failed        # only the failing step's log
```

### 9.4 GitHub (write) — explicit confirmation required
```bash
gh pr create / edit / comment / review / merge / close
gh issue create / edit / comment / close / reopen
gh release create
gh api --method POST|PATCH|PUT|DELETE <endpoint>
```

`gh pr merge` and `gh pr review --approve` are **never** run by an agent on its
own initiative. They require an explicit, unambiguous instruction from the user
in the current conversation.
