# claude-links installer cho Windows PowerShell (5.1 va 7+).
# Chay lai nhieu lan van an toan (dung de cap nhat).
& {
  $ErrorActionPreference = 'Stop'
  $Utf8  = New-Object System.Text.UTF8Encoding $false
  $CL    = Join-Path $HOME '.claude'
  $Hooks = Join-Path $CL 'hooks'
  $Hook  = Join-Path $Hooks 'claude-links-log.ps1'
  New-Item -ItemType Directory -Force -Path $Hooks | Out-Null

  if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    Write-Host "Luu y: lenh 'ol' can fzf. Cai bang: winget install junegunn.fzf"
  }

  # Xoa khoi claude-links cu (neu co). Tra ve $false neu gap khoi kieu cu khong co dau ket thuc.
  function Remove-ClBlock([string]$Path) {
    if (-not (Test-Path $Path)) { return $true }
    $text = [IO.File]::ReadAllText($Path)
    $new  = [regex]::Replace($text, '(?s)[^\r\n]*claude-links:begin.*?claude-links:end[^\r\n]*\r?\n?', '')
    if ($new -match 'claude-links') {
      # Khoi cua ban cai dau tien (khong co dau ket thuc)
      $new = ([regex]'(?s)[^\r\n]*claude-links[^\r\n]*\r?\n.*?(\n\}[^\r\n]*|When printing a bare path[^\r\n]*)\r?\n?').Replace($new, '', 1)
      if ($new -match 'claude-links') {
        Write-Host "Canh bao: khong tu go duoc khoi claude-links cu trong $Path. Hay xoa tay roi chay lai."
        return $false
      }
    }
    if ($new -ne $text) { [IO.File]::WriteAllText($Path, $new, $Utf8) }
    return $true
  }

  function Add-Text([string]$Path, [string]$Text) {
    if (-not (Test-Path $Path)) { [IO.File]::WriteAllText($Path, '', $Utf8) }
    $cur = [IO.File]::ReadAllText($Path)
    if ($cur.Length -gt 0 -and -not $cur.EndsWith("`n")) { $Text = "`n" + $Text }
    [IO.File]::AppendAllText($Path, $Text, $Utf8)
  }

  # 1) Chi dan toan cuc cho moi session
  $md = Join-Path $CL 'CLAUDE.md'
  if (Remove-ClBlock $md) {
    Add-Text $md @'
<!-- claude-links:begin -->
## File paths and URLs in replies
- When referring to a file, folder or URL, write it as a markdown link with a short label: [file-name](absolute-path-or-url).
- Put each link on its own line, never in the middle of a long sentence.
- When printing a bare path, prefer a short path relative to the project root.
<!-- claude-links:end -->

'@
  }

  # 2) Hook ghi lai moi file Claude tao/sua
  $hookCode = @'
# claude-links: ghi duong dan file Claude vua tao/sua
[Console]::InputEncoding = [Text.Encoding]::UTF8
$raw = [Console]::In.ReadToEnd()
try { $j = $raw | ConvertFrom-Json } catch { exit 0 }
$f = $j.tool_input.file_path
if (-not $f) { $f = $j.tool_input.notebook_path }
if ($f) {
  $log = Join-Path $HOME '.claude\recent-files'
  $enc = New-Object Text.UTF8Encoding $false
  [IO.File]::AppendAllText($log, "$f`n", $enc)
  $lines = [IO.File]::ReadAllLines($log)
  if ($lines.Count -gt 1000) { [IO.File]::WriteAllLines($log, $lines[-500..-1], $enc) }
}
exit 0
'@
  [IO.File]::WriteAllText($Hook, $hookCode, $Utf8)
  Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $Hooks 'log-file.ps1')   # hook cua ban cai dau tien

  # 3) Gop hook vao settings.json (giu cau hinh cu, co ban .bak)
  $S = Join-Path $CL 'settings.json'
  $cfg = $null
  if (Test-Path $S) {
    $raw = [IO.File]::ReadAllText($S)
    if ($raw.Trim()) {
      try { $cfg = $raw | ConvertFrom-Json } catch { throw "Loi: $S khong phai JSON hop le, khong sua gi." }
      Copy-Item $S "$S.bak" -Force
    }
  }
  if ($null -eq $cfg) { $cfg = [pscustomobject]@{} }

  $cmd = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + ($Hook -replace '\\', '/') + '"'
  if (-not $cfg.PSObject.Properties['hooks']) {
    $cfg | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{})
  }
  $existing = @()
  if ($cfg.hooks.PSObject.Properties['PostToolUse']) {
    $existing = @($cfg.hooks.PostToolUse | Where-Object {
      -not (@($_.hooks) | Where-Object { "$($_.command)" -match 'claude-links|/hooks/log-file\.(sh|ps1)' })
    })
  }
  $entry = [pscustomobject]@{
    matcher = 'Write|Edit|MultiEdit|NotebookEdit'
    hooks   = @([pscustomobject]@{ type = 'command'; command = $cmd })
  }
  $all = @($existing) + @($entry)
  if ($cfg.hooks.PSObject.Properties['PostToolUse']) { $cfg.hooks.PostToolUse = $all }
  else { $cfg.hooks | Add-Member -NotePropertyName PostToolUse -NotePropertyValue $all }
  [IO.File]::WriteAllText($S, ($cfg | ConvertTo-Json -Depth 20), $Utf8)

  # 4) Lenh `ol` trong profile cua PowerShell 5.1 va 7+
  $olCode = @'
# claude-links:begin
function ol {
  $p = Join-Path $HOME '.claude\recent-files'
  if (-not (Test-Path $p)) { Write-Host 'Chua co file nao.'; return }
  $lines = @([IO.File]::ReadAllLines($p))
  [array]::Reverse($lines)
  $list = $lines | Where-Object { $_ } | Select-Object -Unique
  if (Get-Command fzf -ErrorAction SilentlyContinue) {
    $f = $list | fzf --prompt='Open file: '
  } else {
    $f = $list | Out-GridView -PassThru -Title 'Open file'
  }
  if ($f) { Invoke-Item -LiteralPath $f }
}
# claude-links:end

'@
  $docs = [Environment]::GetFolderPath('MyDocuments')
  if (-not $docs) { $docs = Join-Path $HOME 'Documents' }
  foreach ($dir in @('WindowsPowerShell', 'PowerShell')) {
    $prof = Join-Path (Join-Path $docs $dir) 'profile.ps1'
    New-Item -ItemType Directory -Force -Path (Split-Path $prof) | Out-Null
    if (Remove-ClBlock $prof) { Add-Text $prof $olCode }
  }

  Write-Host 'Da cai claude-links.'
  Write-Host '  - Mo cua so PowerShell moi de dung lenh ol'
  Write-Host '  - Neu profile khong chay: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned'
  Write-Host '  - Khoi dong lai cac session Claude Code dang mo (claude --continue)'
}
