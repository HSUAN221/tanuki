---
name: project-navigator
description: |
  Navigate tanuki architecture and dependency questions.
  Use when asked about project identity, package locations, or dependency requirements before changing code.
argument-hint: "[optional: identity | package | dependency | overview]"
invocation-syntax: |
  claude: /project-navigator package
---

# Project Navigator

## §0 When to Use This Skill
**Use this skill when**:
- The user asks about project identity, mission, tech stack, or constraints.
- The user asks where a package/feature lives or which files to edit.
- The user asks about dependencies, required modules, or `go.mod` contents.

**Do NOT use this skill when**:
- The user wants to build/test (delegate to `build-test-runner`).
- The user requests formatting/lint/audit fixes (delegate to `code-quality`).
- The user requests code review/refactor workflows (delegate to `code-reviewer`).

## §0.5 Anti-Patterns (What NOT to Do)
❌ **WRONG: Answering from memory**
- "tanuki probably uses cobra for its CLI."
- "It's on Go 1.21."

**Problems**:
1. Ignores authoritative guides and `go.mod`.
2. Risks giving incorrect dependency or version requirements.
3. Go module facts change every time `go.mod` changes.

✅ **CORRECT: Use this SKILL**
- "Use project-navigator to look up the required Go version and dependencies."

**What this provides**:
1. Consistent routing to authoritative docs.
2. Reproducible answers with cited sources and live command output.

## §0.6 Why This Matters
**Safety implications**:

| Aspect | Direct Tools | This SKILL |
| --- | --- | --- |
| Accuracy | ❌ Risk of stale memory | ✅ Cites guides and live `go list` output |
| Scope control | ❌ Scope creep | ✅ Focused to intent |

**Real-world consequences**:
- 🚨 Misstated dependencies lead to broken builds or a wrong `go.mod` edit.
- 🚨 Incorrect package paths waste developer time and cause mis-edits.
- 🚨 A guessed Go version produces code that will not compile.

## §0.7 Path Conventions (read first)
See `@.ai/contexts/path-conventions.md`.

## §1 Routing & Classification
**User intent → Guide section mapping**:

| User Intent | Interpret As | Jump to Guide Section |
| --- | --- | --- |
| Project identity / mission / tech stack | Identity lookup | `@.ai/contexts/project-overview.md` → tables + constraints |
| Package location / responsibilities | Codebase navigation | `@.ai/contexts/codebase-guide.md` → §1, §3 |
| "Where do I add X?" | Placement decision | `@.ai/contexts/codebase-guide.md` → §3.2, §5 |
| Dependencies / `go.mod` / module versions | Dependency lookup | `@.ai/contexts/dependency-map.md` → §1 queries |
| "Can I add dependency X?" | Dependency policy | `@.ai/contexts/dependency-map.md` → §3 |
| Naming / layout conventions | Convention lookup | `@.ai/contexts/codebase-guide.md` → §4 |
| Mixed or unclear | Clarify + load overview first | `@.ai/contexts/project-overview.md` → then refine |

## §1.5 Quick Decision Tree (for AI routing)
1. IF question is identity/mission/tech stack → load project-overview → answer.
2. ELSE IF question is package location/responsibilities → load codebase-guide → answer.
3. ELSE IF question is dependencies/versions → load dependency-map → run §1 queries → answer.
4. ELSE IF question is "where should this new code go" → codebase-guide §3.2 + §5.
5. ELSE → ask a clarifying question before proceeding.

## §2 Load Strategy
**Authoritative references**:
- Primary guide → `@.ai/contexts/project-overview.md`
- Supporting files → `@.ai/contexts/codebase-guide.md`, `@.ai/contexts/dependency-map.md`
- Live sources → `go.mod`, `go list -m all`, `git ls-files`

**On-demand load map**:
- Identity questions → project-overview
- Package location → codebase-guide §1/§3
- Dependencies → dependency-map §1/§3

## §3 Execution Protocol
**Pre-flight validation (mandatory)**:
- `REPO_ROOT=$(git rev-parse --show-toplevel) && cd "$REPO_ROOT"`
- Confirm the question classification (identity vs package vs dependency).
- List the guide(s) that will be opened.

**Workflow steps**:
1. Classify the user intent using §1.
2. Load only the necessary guide(s).
3. Run the live query the guide prescribes (`go list`, `git ls-files`, `rg`)
   rather than quoting a table that may be stale.
4. Extract facts verbatim (tables/sections) and quote command output.
5. Respond with structure: classification → citations → next actions.

**Checkpoints**:
- After extraction: at least one citation from an authoritative guide, and, for
  any version or dependency claim, one line of real command output.

## §4 Delegation & Handoffs
**When to invoke other SKILLs**:

| Scenario | Delegate To | Invocation |
| --- | --- | --- |
| Build/test request | `build-test-runner` | "Run tests with build-test-runner" |
| Formatting/lint/audit | `code-quality` | "Use code-quality to audit a file" |
| Review/refactor workflow | `code-reviewer` | "Use code-reviewer for a local review" |
| Commit/PR after changes | `vcs-workflow-manager` | "Help me commit using vcs-workflow-manager" |

## §5 Troubleshooting
### §5.1 Common Failures
| Failure Mode | Symptoms | Root Cause | Recovery Steps |
| --- | --- | --- | --- |
| Missing guide | File not found | Path resolution issue | Re-open using `@.ai/...` path conventions |
| `go: command not found` | Cannot run `go list` | Toolchain absent | Read `go.mod` directly; state that indirect deps are unverified |
| Empty command output | No matches found | Search scope too narrow | Widen the search or ask for clarification |
| Guide contradicts the tree | Table lists a package that does not exist | Guide drifted | Trust the live query; report the drift |
| Ambiguous request | Unclear intent | Mixed requirements | Ask one clarifying question before loading more guides |

### §5.2 Degraded Mode Operations
| Missing Tool | Impact | Fallback Strategy |
| --- | --- | --- |
| `go` | Cannot resolve indirect deps | `cat go.mod`; state the limitation explicitly |
| `rg`/`grep` | Cannot query live data | Rely on guides; report the missing live output |

## §6 Self-Assessment Checklist
- [ ] Request classified with guide section references
- [ ] Required guide sections loaded and cited
- [ ] Pre-flight validation completed
- [ ] Live queries executed with stdout captured (if any)
- [ ] Version/dependency claims backed by real output, not memory
- [ ] Next steps provided to user
