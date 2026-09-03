---
name: vcs-workflow-manager
description: |
  Orchestrate Git/GitHub workflows with automated safety checks and policy
  enforcement for tanuki. Use when: (1) committing/pushing code with
  validation, (2) creating/updating pull requests, (3) managing GitHub
  issues/labels, (4) creating issues from repository templates,
  (5) responding to reviewer feedback, (6) checking CI/workflow status,
  (7) cutting releases, or (8) diagnosing version control errors. Enforces
  commit standards, branch policies, and confirmation prompts for remote writes.
argument-hint: |
  [optional: commit | pr | inline-note | issue | branch | ci | release | help]
  - commit: Guide staging, committing, and pushing with policy checks
  - pr: Create/update pull requests and coordinate with reviewers
  - inline-note: Post a line-level review comment on a PR diff
  - issue: Create issues from templates, update status/labels, or post progress notes
  - branch: Explain branch strategy and naming conventions
  - ci: Check GitHub Actions status and diagnose failures
  - release: Tag and publish a release
  - help: Show the workflow decision matrix and guide routing
invocation-syntax: |
  claude: /vcs-workflow-manager commit
---

# VCS Workflow Manager

## §0 When to Use This Skill
**Use this skill when**:
- The user requests multi-step Git/GitHub operations (commit + push, create PR, create issue, respond to feedback).
- The operation mutates remote state and therefore requires explicit confirmation.
- The user needs policy guidance (branch naming, commit format, collaboration rules).
- The user encounters Git/GitHub errors and needs diagnosis + recovery.

**Do NOT use this skill when**:
- The request is a simple read-only query (e.g. "show git status").
- The user explicitly prefers manual execution (provide commands only).
- The request is unrelated to version control.

## §0.5 Anti-Patterns (What NOT to Do)
❌ **WRONG: Direct bash execution without SKILL**

**Scenario**: User says "git add and commit"
```
git add -A
git commit -m "fix: update code"
git push
```

**Problems**:
1. No commit message validation (missing Issue reference, non-conventional subject).
2. No branch name validation, and no check that the branch is not `main`.
3. `git add -A` sweeps in secrets, `bin/`, and `coverage.out`.
4. No quality gate — unformatted, unvetted, untested code reaches the remote.
5. No confirmation gate for the remote write.
6. Violates `@.ai/contexts/vcs-workflow-guide.md` §4.2 prerequisites.

✅ **CORRECT: Use this SKILL**
```
Use vcs-workflow-manager to commit
```

**What this provides**:
1. Context gathering (§3.0) to extract the repo slug, branch, and issue id.
2. Branch and commit-message policy validation (guide §1.1, §1.2).
3. A quality gate (`gofmt`, `go vet`, `go test`) before the commit.
4. Explicit staging, with a secret scan on the staged diff.
5. A confirmation gate before the push, and read-back verification after.

## §0.6 Why This Matters
**Safety implications**:

| Aspect | Direct Bash | This SKILL |
| --- | --- | --- |
| Commit format validation | ❌ None | ✅ Enforced |
| Branch naming check | ❌ None | ✅ Validated |
| Direct-to-`main` guard | ❌ None | ✅ Refused |
| Issue reference | ❌ Manual | ✅ Auto-extracted from the branch |
| Quality gate before commit | ❌ None | ✅ Required |
| Secret scan on the staged diff | ❌ None | ✅ Required |
| Confirmation for remote writes | ❌ None | ✅ Required |
| Read-back verification | ❌ None | ✅ Required |
| Error recovery | ❌ Manual | ✅ Guided |

**Real-world consequences**:
- 🚨 Commits without an issue reference → untraceable history.
- 🚨 `git add -A` → a committed credential; rotation is then mandatory.
- 🚨 `git push --force` → a colleague's work erased.
- 🚨 An agent-approved PR → human review silently bypassed.

## §0.7 Anti-Patterns: GitHub CLI and API pitfalls

❌ **Inline Markdown in a comment body**
```bash
gh pr comment 12 -b "run `go test ./...` to verify"
```
The shell executes what is inside the backticks and posts the *output*. This is
both a correctness bug and a command-execution hazard.
✅ Write to a file with a quoted heredoc, then `--body-file`.

❌ **Treating HTTP 200 as verification**
An inline comment with an invalid position may be accepted and silently
downgraded to a plain comment.
✅ Read back and require `.path` and `.line` to be non-null (guide §3.3.2 step 5).

❌ **A stale `commit_id` on an inline comment**
```bash
gh api ... -f commit_id="$OLD_SHA"      # 422, or the comment lands on the wrong line
```
✅ Re-fetch `gh api "repos/$SLUG/pulls/$PR" -q .head.sha` immediately before posting.

❌ **Commenting on a line that is not in the diff**
GitHub rejects it with 422. ✅ Confirm the line appears in a hunk of
`pulls/<n>/files` before building the payload.

❌ **`select(.resolved == false)` on REST payloads**
Records that omit the field are missed entirely.
✅ `select((.resolved // false) == false)`, or use the GraphQL
`reviewThreads.isResolved` field (guide §7.2).

❌ **`gh` hanging with no output**
It is waiting on an interactive pager. ✅ `export GH_PAGER=cat` in scripted contexts.

❌ **Hard-coding the repo slug**
✅ Derive it from the remote (guide §3.0), so forks and renames keep working.

## §0.8 Path Conventions (read first)
See `@.ai/contexts/path-conventions.md`.

## §1 Routing & Classification
**User intent → Guide section mapping**:

| User Intent | Interpret As | Jump to Guide Section |
| --- | --- | --- |
| "Commit my changes" | Commit workflow | `@.ai/contexts/vcs-workflow-guide.md` → **§3.1**, **§4.2** |
| "Create a pull request" | PR creation | `@.ai/contexts/vcs-workflow-guide.md` → **§3.2**, **§4.2** |
| "Respond to reviewer feedback" | PR collaboration | `@.ai/contexts/vcs-workflow-guide.md` → **§3.3** |
| "Post a summary comment" | PR note | `@.ai/contexts/vcs-workflow-guide.md` → **§3.3.1** |
| "Post an inline/line-level comment" | Positional review comment | `@.ai/contexts/vcs-workflow-guide.md` → **§3.3.2** |
| "Create an issue" | Issue creation | `@.ai/contexts/vcs-workflow-guide.md` → **§3.4** + `@.ai/contexts/issue-workflow-guide.md` + the selected `.github/ISSUE_TEMPLATE/<template>.md` |
| "Update issue labels/status" | Issue update | `@.ai/contexts/vcs-workflow-guide.md` → **§3.4** |
| "Check CI status" | CI query | `@.ai/contexts/vcs-workflow-guide.md` → **§9.3** |
| "Which branch should I use?" | Branch strategy | `@.ai/contexts/vcs-workflow-guide.md` → **§1.1** |
| "Fix a production bug now" | Emergency hotfix | `@.ai/contexts/vcs-workflow-guide.md` → **§3.5** |
| "Cut a release" | Release management | `@.ai/contexts/vcs-workflow-guide.md` → **§6.1** |
| "Extract PR/issue data" | API-assisted ops | `@.ai/contexts/vcs-workflow-guide.md` → **§3.6**, **§7** |

## §1.5 Quick Decision Tree (for AI routing)
```
Priority-ordered routing (check in order):
1. IF "commit" OR "push" → Load §3.1 + §4.2 → Execute commit workflow
2. ELSE IF "PR"/"pull request"/"MR" AND ("create" OR "new" OR "open") → Load §3.2
3. ELSE IF "issue" AND ("create" OR "new" OR "file" OR "open") → Load §3.4 + issue-workflow guide + the selected template → Draft, confirm, create, verify
4. ELSE IF "inline" OR "line-level" OR "行內" OR "區塊留言" → Load §3.3.2 → Execute the positional-comment workflow
5. ELSE IF "PR" AND ("feedback" OR "review" OR "comment") → Load §3.3
6. ELSE IF "issue"/"PR" AND ("info" OR "number" OR "list" OR "show") → Load §3.6 + §7 → Data extraction
7. ELSE IF "issue" OR "label" → Load §3.4 + issue-workflow guide
8. ELSE IF "CI" OR "pipeline" OR "actions" OR "checks" → Load §9.3
9. ELSE IF "release" OR "tag" OR "version" → Load §6.1
10. ELSE IF "error" OR "failed" OR "rejected" → Load §5 → Diagnose + recover
11. ELSE IF "hotfix" OR "production" → Load §3.5
12. ELSE → Ask a clarifying question using the §1 table
```

## §2 Load Strategy
**Authoritative references**:
- Primary guide → `@.ai/contexts/vcs-workflow-guide.md`
- Issue template guide → `@.ai/contexts/issue-workflow-guide.md`

**On-demand load map**:
- Commit/push → §3.1 + §4
- PR workflows → §3.2/§3.3 + §4
- Inline review comment → §3.3.2 (read it in full; the payload shape matters)
- Issue creation/update → §3.4 + issue-workflow guide + `.github/ISSUE_TEMPLATE/<template>.md`
- Hotfix → §3.5
- Release → §6.1
- Data extraction → §3.6 + §7
- Troubleshooting → §5

## §3 Execution Protocol
**Pre-flight validation (mandatory)**:
- ⚠️ **CRITICAL**: before executing ANY `gh` command, read
  `@.ai/contexts/vcs-workflow-guide.md` §3.0 for the correct syntax.
- Execute §3.0 context gathering and record: repo slug, branch, dirty state,
  ahead/behind, PR number, issue id.
- Use ONLY commands documented in the guide. Do not improvise flags from
  training data — verify with `gh <command> --help` when uncertain.
- Confirm environment context before asking the user anything (`pwd`,
  `git remote -v`, `git branch --show-current`, `gh auth status`).
- Refuse outright if the current branch is `main` and the request is a write
  (guide §1.1).

**Workflow steps**:
1. Classify the request using §1.
2. Load the required guide sections.
3. Apply pre-flight checks: branch policy, sync state, auth, quality gate.
4. For issue creation, select the template per `issue-workflow-guide.md` §1.1,
   read `.github/ISSUE_TEMPLATE/<template>.md`, and fill in only that
   template's sections (strip the YAML front matter before posting).
5. Preview the exact command and full body; require explicit confirmation for
   every remote write.
6. Execute, capturing stdout, stderr, and the exit code.
7. Verify with a follow-up read command. Compare the read-back to what you sent.

**Checkpoints**:
- After commit: `git status -sb` and `git log -1 --stat`.
- After push: `git status -sb` shows the branch up to date with its remote.
- After a GitHub write: a read-back (`gh pr view`, `gh issue view`, or the API
  response) confirming the content survived intact.

### §3.1 Quality gate before any commit
Delegate to `build-test-runner`, or run and record:
```bash
test -z "$(gofmt -l .)" || { echo "STOP: unformatted files"; gofmt -l .; exit 1; }
go vet ./... || exit 1
go test -race -count=1 ./... || exit 1
```
A failing gate is a stop condition, not a warning. Report it and do not commit.

### §3.2 Secret scan before any commit
```bash
git diff --cached | grep -inE '(api[_-]?key|secret|token|password|BEGIN .*PRIVATE KEY)' \
  && echo "STOP: possible secret in the staged diff — review before committing"
```
If a secret was already committed and pushed: **rotate the credential first**,
then purge history. Purging alone is not remediation.

### §3.3 Post a PR comment (safe Markdown handling)
**Purpose**: post Markdown to a PR without shell interpretation issues.

**Problem**: `-b "content"` lets the shell interpret backticks, `$`, and quotes.

**Workflow**: follow guide §3.3.1 exactly —
1. Write the body to a file using a **quoted** heredoc (`<<'NOTE'`).
2. Preview the file contents to the user; get confirmation.
3. Post with `gh pr comment <n> --body-file <path>`.
4. Read back the latest comment and compare it to the file. A mismatch means
   repost, not "close enough".

### §3.4 Post a line-level (inline) review comment
Follow guide §3.3.2 in full. Non-negotiable steps:
1. Fetch the **current** head SHA: `gh api "repos/$SLUG/pulls/$PR" -q .head.sha`.
2. Confirm the target file and line appear in `pulls/$PR/files`. If not, STOP —
   the line is not in the diff and cannot carry an inline comment.
3. Build the payload as a JSON file and post with `gh api --input`, never with
   inline `-f` for the positional fields.
4. Verify the response has non-null `.path` and `.line`. HTTP 200 alone is not
   verification — an invalid position is silently downgraded to a plain comment.
5. For several findings, use one batched review
   (`POST repos/$SLUG/pulls/$PR/reviews` with a `comments` array) rather than N
   individual posts — one notification instead of N.
6. `event` MUST be `COMMENT`. Never `APPROVE` or `REQUEST_CHANGES` without an
   explicit user instruction in the current conversation.

## §4 Delegation & Handoffs
**When to invoke other SKILLs**:

| Scenario | Delegate To | Invocation |
| --- | --- | --- |
| Quality gate before commit | `build-test-runner` | "Run the gate with build-test-runner" |
| Formatting failures | `code-quality` | "Use code-quality to format the tree" |
| Code review / refactor | `code-reviewer` | "Use code-reviewer for a local review" |
| "Where does this change belong?" | `project-navigator` | "Use project-navigator for placement" |

## §5 Troubleshooting
### §5.1 Common Failures
| Failure Mode | Symptoms | Root Cause | Recovery Steps |
| --- | --- | --- | --- |
| Non-fast-forward push | `! [rejected]` | Branch behind remote | `git fetch origin && git rebase origin/<branch>` |
| Merge conflict | `CONFLICT (content)` | Overlapping edits | Resolve, `git add`, `git rebase --continue` |
| Commit on `main` requested | — | Policy violation | Refuse; cite guide §1.1; offer to create a branch |
| Commit message rejected | Hook error / policy check | Non-conventional subject | Fix per guide §1.2 |
| Auth failure | `HTTP 401` | Token expired | Ask the USER to run `gh auth login`; an agent never runs an interactive login |
| Missing scope | `HTTP 404` on an existing repo | Token lacks `repo` | `gh auth refresh -s repo` (user-run) |
| Rate limited | `HTTP 403` | Too many requests | `gh api rate_limit`; back off; use `--paginate` instead of a loop |
| Invalid diff position | `HTTP 422 ... line ... invalid` | Target line not in the diff | Re-read `pulls/<n>/files`; pick a line inside a hunk |
| Stale commit_id | `HTTP 422` on `commit_id` | The PR was pushed to since | Re-fetch `.head.sha` and retry |
| Inline note downgraded | 200 OK but no anchor | Invalid `position` payload | Read back; require non-null `.path`/`.line`; repost |
| Shell command substitution | `command not found` in a posted comment | Backticks in `-b` | Use `--body-file`; verify by read-back |
| Editor opened unexpectedly | Blocks on vim | Missing `-m`/`-F` in a non-interactive shell | Use `git commit -F <file>` |
| `gh` hangs | No output, no exit | Interactive pager | `export GH_PAGER=cat` |
| UTF-8 garbled | Chinese text mangled | Locale mismatch | Set a UTF-8 locale before posting; verify by read-back |
| Verification timeout | Latest comment not found | API propagation delay | Wait ~5s and retry once; then report, do not loop |
| Secret committed | Credential in history | `git add -A` | **Rotate the credential first**, then purge history, then inform the team |
| Lost commits after a reset | Work "gone" | Hard reset | `git reflog` → `git reset --hard <sha>` |

### §5.2 Degraded Mode Operations
| Missing Tool | Impact | Fallback Strategy |
| --- | --- | --- |
| `gh` | Cannot manage PRs/issues | Git-only guidance; give the user the exact `gh` commands to run; do NOT claim a PR was created |
| `jq` | Cannot parse API JSON | Use `gh ... --json <fields> -q <expr>`; otherwise report raw output |
| `go` | Cannot run the quality gate | Report that the gate was skipped; recommend not pushing until it can run |

## §6 Self-Assessment Checklist
- [ ] §3.0 context gathering completed (slug, branch, PR, issue id recorded)
- [ ] Branch policy validated; not committing to `main`
- [ ] Quality gate run and green (`gofmt`, `go vet`, `go test -race`)
- [ ] Staged diff reviewed explicitly and secret-scanned
- [ ] Commit message validated against guide §1.2
- [ ] Bodies written to files and passed via `-F` / `--body-file`
- [ ] Explicit confirmation obtained for every remote write
- [ ] Commands executed with stdout/stderr and exit codes captured
- [ ] Every remote write verified by read-back, not by HTTP status
- [ ] No `--force`, no APPROVE/REQUEST_CHANGES, no merge without explicit instruction
- [ ] Next steps provided to user
