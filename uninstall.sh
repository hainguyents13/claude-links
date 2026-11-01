#!/usr/bin/env bash
# Gỡ claude-links trên macOS / Linux.
set -euo pipefail
CL="$HOME/.claude"
BEGIN="claude-links:begin"; END="claude-links:end"

strip_block() {
  local f="$1"
  [ -f "$f" ] || return 0
  if grep -q "$BEGIN" "$f" && grep -q "$END" "$f"; then
    awk -v b="$BEGIN" -v e="$END" 'index($0,b){skip=1} !skip{print} index($0,e){skip=0}' "$f" > "$f.tmp"
    cat "$f.tmp" > "$f" && rm -f "$f.tmp"
  fi
}

for f in "$CL/CLAUDE.md" "$HOME/.zshrc" "$HOME/.bashrc"; do strip_block "$f"; done

S="$CL/settings.json"
if [ -f "$S" ] && command -v jq >/dev/null 2>&1 && jq empty "$S" 2>/dev/null; then
  cp "$S" "$S.bak"
  jq '
    if .hooks.PostToolUse then
      .hooks.PostToolUse |= map(select(any(.hooks[]?; (.command // "") | test("claude-links")) | not))
      | if (.hooks.PostToolUse | length) == 0 then del(.hooks.PostToolUse) else . end
      | if (.hooks | length) == 0 then del(.hooks) else . end
    else . end
  ' "$S.bak" > "$S"
fi

rm -f "$CL/hooks/claude-links-log.sh" "$CL/recent-files"
echo "✓ Đã gỡ claude-links. Mở terminal mới và khởi động lại Claude Code."
