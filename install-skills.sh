#!/bin/bash
# install-skills.sh
# Downloads and installs 3 community Claude skills into your Cowork skills folder.
# Run this from your terminal: bash install-skills.sh

set -e

# ── Find the skills directory ───────────────────────────────────────────────
# Cowork stores skills in the .claude/skills folder *above* your project folder.
# This script assumes it lives next to your project folder.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$(dirname "$SCRIPT_DIR")/.claude/skills"

echo "📂 Installing skills to: $SKILLS_DIR"
mkdir -p "$SKILLS_DIR"

# ── 1. emilkowalski/skill ────────────────────────────────────────────────────
echo ""
echo "⬇️  Downloading emilkowalski/skill (design engineering taste)..."
mkdir -p "$SKILLS_DIR/emil-design-eng"
curl -fsSL \
  "https://raw.githubusercontent.com/emilkowalski/skill/main/skills/emil-design-eng/SKILL.md" \
  -o "$SKILLS_DIR/emil-design-eng/SKILL.md"
echo "   ✅ emil-design-eng installed"

# ── 2. pbakaus/impeccable ────────────────────────────────────────────────────
echo ""
echo "⬇️  Downloading pbakaus/impeccable (design language / UI polish)..."
TMP_IMP=$(mktemp -d)
git clone --depth=1 https://github.com/pbakaus/impeccable.git "$TMP_IMP/impeccable" 2>/dev/null
# impeccable ships its Claude Code skills inside dist/claude-code/.claude/skills/
if [ -d "$TMP_IMP/impeccable/dist/claude-code/.claude/skills" ]; then
  cp -r "$TMP_IMP/impeccable/dist/claude-code/.claude/skills/." "$SKILLS_DIR/"
elif [ -d "$TMP_IMP/impeccable/.claude/skills" ]; then
  cp -r "$TMP_IMP/impeccable/.claude/skills/." "$SKILLS_DIR/"
else
  echo "   ⚠️  Could not find skill files in impeccable — check $TMP_IMP/impeccable manually"
fi
rm -rf "$TMP_IMP"
echo "   ✅ impeccable installed"

# ── 3. Leonxlnx/taste-skill ─────────────────────────────────────────────────
echo ""
echo "⬇️  Downloading Leonxlnx/taste-skill (anti-slop frontend taste)..."
mkdir -p "$SKILLS_DIR/taste-skill"
curl -fsSL \
  "https://raw.githubusercontent.com/Leonxlnx/taste-skill/main/skills/taste-skill/SKILL.md" \
  -o "$SKILLS_DIR/taste-skill/SKILL.md"
# Also grab any reference files if they exist
curl -fsSL \
  "https://raw.githubusercontent.com/Leonxlnx/taste-skill/main/skills/taste-skill/references/design-principles.md" \
  -o "$SKILLS_DIR/taste-skill/design-principles.md" 2>/dev/null || true
echo "   ✅ taste-skill installed"

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "🎉 All 3 skills installed!"
echo ""
echo "Installed:"
ls "$SKILLS_DIR"
