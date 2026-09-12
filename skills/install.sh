#!/bin/sh
# Installs the Foldy agent skill into every agent skills directory found on this machine.
#   curl -fsSL https://raw.githubusercontent.com/tornikegomareli/foldy/main/skills/install.sh | sh
set -e
src="https://raw.githubusercontent.com/tornikegomareli/foldy/main/skills/foldy/SKILL.md"
installed=0
for dir in "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.pi/skills"; do
  [ -d "$(dirname "$dir")" ] || continue
  mkdir -p "$dir/foldy"
  curl -fsSL "$src" -o "$dir/foldy/SKILL.md"
  echo "installed $dir/foldy/SKILL.md"
  installed=1
done
if [ "$installed" = 0 ]; then
  mkdir -p "$HOME/.claude/skills/foldy"
  curl -fsSL "$src" -o "$HOME/.claude/skills/foldy/SKILL.md"
  echo "installed $HOME/.claude/skills/foldy/SKILL.md"
fi
