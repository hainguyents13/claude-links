#!/usr/bin/env bash
# claude-links installer cho macOS / Linux. Chay lai nhieu lan van an toan (dung de cap nhat).
set -euo pipefail

CL="$HOME/.claude"
BEGIN="claude-links:begin"
END="claude-links:end"
HOOK="$CL/hooks/claude-links-log.sh"

say() { printf '%s\n' "$*"; }

command -v jq >/dev/null 2>&1 || { say "Thiếu jq. macOS: brew install jq | Ubuntu/Debian: sudo apt install jq"; exit 1; }
command -v fzf >/dev/null 2>&1 || say "Lưu ý: lệnh 'ol' cần fzf. macOS: brew install fzf | Ubuntu/Debian: sudo apt install fzf"

mkdir -p "$CL/hooks"

# Xoá khối claude-links cũ (nếu có) để ghi bản mới. Trả về 1 nếu gặp khối kiểu cũ không có dấu kết thúc.
strip_block() {
  local f="$1"
  [ -f "$f" ] || return 0
  if grep -q "$BEGIN" "$f" && grep -q "$END" "$f"; then
    awk -v b="$BEGIN" -v e="$END" 'index($0,b){skip=1} !skip{print} index($0,e){skip=0}' "$f" > "$f.tmp"
    cat "$f.tmp" > "$f" && rm -f "$f.tmp"   # giữ nguyên symlink của dotfiles
  elif grep -q "claude-links" "$f"; then
    # Khối của bản cài đầu tiên (không có dấu kết thúc): xoá đến dòng "}" hoặc dòng chỉ dẫn cuối cùng
    awk 'index($0,"claude-links") && !done {skip=1}
         !skip {print}
         skip && ($0 ~ /^}/ || index($0,"When printing a bare path")) {skip=0; done=1}' "$f" > "$f.tmp"
    if grep -q "claude-links" "$f.tmp"; then
      rm -f "$f.tmp"
      say "Cảnh báo: không tự gỡ được khối claude-links cũ trong $f. Hãy xoá tay rồi chạy lại."
      return 1
    fi
    cat "$f.tmp" > "$f" && rm -f "$f.tmp"
  fi
}

# 1) Chỉ dẫn toàn cục cho mọi session
MD="$CL/CLAUDE.md"
touch "$MD"
if strip_block "$MD"; then
cat >> "$MD" <<'EOF'
<!-- claude-links:begin -->
## File paths and URLs in replies
- When referring to a file, folder or URL, write it as a markdown link with a short label: [file-name](absolute-path-or-url).
- Put each link on its own line, never in the middle of a long sentence.
- When printing a bare path, prefer a short path relative to the project root.
<!-- claude-links:end -->
EOF
fi

# 2) Hook ghi lại mọi file Claude tạo/sửa
cat > "$HOOK" <<'EOF'
#!/usr/bin/env bash
# claude-links: ghi đường dẫn file Claude vừa tạo/sửa
log="$HOME/.claude/recent-files"
f=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)
[ -n "$f" ] && printf '%s\n' "$f" >> "$log"
if [ -f "$log" ] && [ "$(wc -l < "$log")" -gt 1000 ]; then
  tail -n 500 "$log" > "$log.tmp" && mv "$log.tmp" "$log"
fi
exit 0
EOF
chmod +x "$HOOK"
rm -f "$CL/hooks/log-file.sh"   # hook của bản cài đầu tiên

# 3) Gộp hook vào settings.json (giữ cấu hình cũ, có bản .bak)
S="$CL/settings.json"
[ -s "$S" ] || echo '{}' > "$S"
jq empty "$S" 2>/dev/null || { say "Lỗi: $S không phải JSON hợp lệ, không sửa gì."; exit 1; }
cp "$S" "$S.bak"
jq --arg cmd "$HOOK" '
  .hooks.PostToolUse =
    ((.hooks.PostToolUse // []) | map(select(any(.hooks[]?; (.command // "") | test("claude-links|/hooks/log-file\\.(sh|ps1)")) | not)))
    + [{"matcher": "Write|Edit|MultiEdit|NotebookEdit",
        "hooks": [{"type": "command", "command": $cmd}]}]
' "$S.bak" > "$S"

# 4) Lệnh `ol` trong shell
case "$(basename "${SHELL:-zsh}")" in
  bash) RC="$HOME/.bashrc" ;;
  *)    RC="$HOME/.zshrc" ;;
esac
touch "$RC"
if strip_block "$RC"; then
cat >> "$RC" <<'EOF'
# claude-links:begin
ol() {
  local f
  [ -s "$HOME/.claude/recent-files" ] || { echo "Chưa có file nào."; return 1; }
  f=$(awk '{a[NR]=$0} END{for(i=NR;i>0;i--) if(!s[a[i]]++) print a[i]}' "$HOME/.claude/recent-files" \
      | fzf --prompt="Mở file: ") || return
  if [ "$(uname)" = "Darwin" ]; then open "$f"; else xdg-open "$f" >/dev/null 2>&1 & fi
}
# claude-links:end
EOF
fi

say "✓ Đã cài claude-links."
say "  • Chạy: source $RC  (hoặc mở terminal mới) để dùng lệnh ol"
say "  • Khởi động lại các session Claude Code đang mở (claude --continue)"
