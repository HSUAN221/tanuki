# tanuki: Terminology & Glossary

This glossary defines canonical terms used across tanuki guides, skills, and
contexts. Use these terms consistently to reduce ambiguity in workflows and
cross-references.

---

## §1 Canonical Terms

| Term | Definition | Usage Notes |
| --- | --- | --- |
| **agentic AI assistant** | An AI system that follows structured workflows, tool routing, and verification steps. | Use lowercase "agentic AI" in body text. Use "Agentic AI" only in headings/titles. |
| **automation script** | Non-interactive tooling that executes guide steps programmatically. | Prefer "automation script(s)" over "automation" alone. |
| **human developer** | A human user following the guides manually. | Use "human developer(s)" (lowercase). |
| **skill** | A specialized orchestration module (e.g., `code-quality`, `vcs-workflow-manager`). | Always lowercase in body text; keep proper names in code blocks. |
| **context** | A source-of-truth guide under `.ai/contexts/`. | Use when referring to documentation files. |
| **guide** | A document that defines policy or workflows (e.g., "VCS Workflow Guide"). | Interchangeable with "context" only when explicitly referencing files. |
| **adapter** | A per-tool directory (`.claude/`, `.codex/`, `.gemini/`, `.opencode/`) holding a generated copy of the agent instructions and skills. | Adapters are generated; `.claude/` is canonical. |
| **workflow** | An ordered set of steps with inputs, outputs, and stop conditions. | Use for step-by-step procedures. |
| **pre-flight validation** | Mandatory checks before running a workflow. | Always hyphenate "pre-flight". |
| **stop condition** | A condition that requires halting or branching the workflow. | Use in step lists and safety gates. |
| **verification** | Follow-up checks that confirm the expected outcome. | Use for "query → act → verify" loops. |
| **section ID** | Stable section identifier (e.g., §3.2). | Use the "§X.Y" format consistently. |
| **PR** | Pull request. | Spell out "pull request (PR)" on first mention per document. |
| **issue** | A tracked work item in GitHub Issues. | Use "Issue: #<id>" when required by VCS policy. |
| **review thread** | A GitHub review conversation, either a summary comment or one anchored to a diff line. | Distinguish from a plain issue comment. |
| **inline comment** | A review comment anchored to a specific file and line in a PR diff. | Requires `path` plus `line`/`start_line` and `side`. |
| **side** | Which half of the diff a comment anchors to: `LEFT` (pre-image) or `RIGHT` (post-image). | Default to `RIGHT` for added/changed lines. |
| **package pattern** | A Go tool argument such as `./...` or `./internal/...`. | Not a filesystem path; resolves relative to cwd. |
| **exported identifier** | A Go identifier beginning with an uppercase letter, visible outside its package. | Requires a doc comment starting with the identifier name. |

---

## §2 Consistency Rules

1. **Casing**: use lowercase for roles ("agentic AI assistant", "automation
   script", "human developer") in body text.
2. **First mention**: spell out "pull request (PR)" once per document, then use "PR".
3. **Cross-references**: cite contexts with `@.ai/contexts/<file>.md` and
   sections with §X.Y.
4. **Hyphenation**: use "pre-flight", "follow-up", and "step-by-step".
5. **Terminology drift**: if a new term is introduced, add it here before using
   it elsewhere.
