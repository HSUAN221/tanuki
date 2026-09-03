#!/usr/bin/env bash
# Sync the AI agent configuration from the canonical .claude/ tree to the
# per-tool adapters (.codex/, .gemini/, .opencode/).
#
# .claude/ is the SINGLE SOURCE OF TRUTH. Never edit an adapter directly;
# edit .claude/ and re-run this script.
#
# Usage:
#   scripts/sync-ai-config.sh            # regenerate the adapters
#   scripts/sync-ai-config.sh --check    # verify they are in sync (exit 1 if not)
#
# The only difference between adapters is how a skill is invoked:
#   claude   → /skill-name
#   codex    → $skill-name
#   gemini   → activate_skill skill-name
#   opencode → /skill-name

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

CHECK_ONLY=false
[ "${1:-}" = "--check" ] && CHECK_ONLY=true

SRC_DOC=".claude/CLAUDE.md"
SRC_SKILLS=".claude/skills"

SKILLS=(project-navigator build-test-runner vcs-workflow-manager code-quality code-reviewer)

# transform <tool> — rewrite skill invocations on stdin for the target tool.
transform() {
    local tool="$1"
    local script=""

    for skill in "${SKILLS[@]}"; do
        case "$tool" in
            codex)    script+="s|/${skill}|\$${skill}|g;" ;;
            gemini)   script+="s|/${skill}|activate_skill ${skill}|g;" ;;
            opencode) : ;;   # identical to claude
        esac
    done

    # The invocation-syntax front-matter label names the host tool.
    script+="s|^  claude: |  ${tool}: |;"

    sed -e "$script"
}

emit() {
    # emit <dest> <content-producing-command...>
    local dest="$1"; shift
    if $CHECK_ONLY; then
        if [ ! -f "$dest" ]; then
            echo "OUT OF SYNC (missing): $dest"; return 1
        fi
        if ! "$@" | diff -q - "$dest" >/dev/null; then
            echo "OUT OF SYNC: $dest"; return 1
        fi
    else
        mkdir -p "$(dirname "$dest")"
        "$@" > "$dest"
    fi
    return 0
}

render_doc()   { transform "$1" < "$SRC_DOC"; }
render_skill() { transform "$1" < "$SRC_SKILLS/$2/SKILL.md"; }

status=0

for tool in codex gemini opencode; do
    case "$tool" in
        codex)    doc=".codex/AGENTS.md"    ;;
        gemini)   doc=".gemini/GEMINI.md"   ;;
        opencode) doc=".opencode/AGENTS.md" ;;
    esac

    emit "$doc" render_doc "$tool" || status=1

    for skill in "${SKILLS[@]}"; do
        emit ".${tool}/skills/${skill}/SKILL.md" render_skill "$tool" "$skill" || status=1
    done
done

if $CHECK_ONLY; then
    if [ $status -eq 0 ]; then
        echo "✅ AI config adapters are in sync with .claude/"
    else
        echo ""
        echo "❌ Adapters are stale. Run: scripts/sync-ai-config.sh"
    fi
    exit $status
fi

echo "✅ Synced .claude/ → .codex/ .gemini/ .opencode/"
echo "   1 agent doc + ${#SKILLS[@]} skills per tool"
