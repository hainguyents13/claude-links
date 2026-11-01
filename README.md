# claude-links

Giúp mở được file, ảnh, folder và link mà **Claude Code** trả về trong terminal, kể cả khi đường dẫn quá dài và bị ngắt dòng.

- **Link ngắn:** Claude được hướng dẫn in đường dẫn dưới dạng link có nhãn ngắn, mỗi link một dòng. Trên terminal hỗ trợ hyperlink, chỉ cần Cmd/Ctrl + click.
- **Lệnh `ol`:** mọi file Claude tạo hoặc sửa đều được ghi lại tự động. Gõ `ol` ở bất kỳ terminal nào để chọn và mở file, không cần click.

Cài một lần, áp dụng cho mọi dự án và mọi session Claude Code trên máy.

## Cài đặt

**macOS / Linux** (cần `jq`, nên có `fzf`: `brew install jq fzf`)

```bash
curl -fsSL https://raw.githubusercontent.com/hainguyents13/claude-links/main/install.sh | bash
```

**Windows PowerShell** (nên có `fzf`: `winget install junegunn.fzf`)

```powershell
irm https://raw.githubusercontent.com/hainguyents13/claude-links/main/install.ps1 | iex
```

Sau khi cài, mở terminal mới và khởi động lại các session Claude Code đang mở (`claude --continue` để quay lại session gần nhất).

**Cập nhật:** chạy lại đúng lệnh cài. Script an toàn khi chạy nhiều lần.

## Sử dụng

Làm việc với Claude Code như bình thường. Khi cần mở một file Claude vừa tạo hoặc sửa, gõ:

```
ol
```

File mới nhất nằm sát dấu nhắc. Gõ vài chữ để lọc, Enter để mở bằng ứng dụng mặc định.

## Gỡ cài đặt

```bash
curl -fsSL https://raw.githubusercontent.com/hainguyents13/claude-links/main/uninstall.sh | bash
```

```powershell
irm https://raw.githubusercontent.com/hainguyents13/claude-links/main/uninstall.ps1 | iex
```

## Script thay đổi những gì

| File | Thay đổi |
| --- | --- |
| `~/.claude/CLAUDE.md` | Thêm khối chỉ dẫn in link ngắn (giữa `claude-links:begin` và `claude-links:end`) |
| `~/.claude/settings.json` | Thêm một hook `PostToolUse`, giữ nguyên cấu hình cũ, lưu bản sao `.bak` |
| `~/.claude/hooks/claude-links-log.*` | Script hook ghi đường dẫn vào `~/.claude/recent-files` (tự giới hạn khoảng 500–1000 dòng) |
| `~/.zshrc` hoặc `~/.bashrc` / PowerShell `profile.ps1` | Thêm hàm `ol` |

Mọi khối được đánh dấu rõ ràng để gỡ sạch. Hãy đọc script trước khi chạy `curl | bash` hoặc `irm | iex`.

## Terminal nên dùng

Link rút gọn chỉ click được trên terminal hỗ trợ hyperlink OSC 8:

- **Windows:** Windows Terminal (không dùng cửa sổ PowerShell cũ).
- **macOS:** iTerm2, Ghostty, WezTerm, Kitty. Terminal.app có thể không hỗ trợ.
- Terminal tích hợp của VS Code.

Lệnh `ol` chạy trên mọi terminal.

## Lưu ý

- Chỉ áp dụng cho Claude Code (CLI và extension VS Code/JetBrains dùng chung `~/.claude`), không áp dụng cho Claude Desktop hay claude.ai.
- Chỉ dẫn link ngắn là hướng dẫn cho Claude, không phải quy tắc cứng. Thỉnh thoảng Claude vẫn có thể in đường dẫn dài, khi đó dùng `ol`.
- Nếu `profile.ps1` không chạy trên Windows: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.
