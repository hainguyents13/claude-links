# Go claude-links tren Windows PowerShell.
& {
  $ErrorActionPreference = 'Stop'
  $Utf8 = New-Object System.Text.UTF8Encoding $false
  $CL   = Join-Path $HOME '.claude'

  function Remove-ClBlock([string]$Path) {
    if (-not (Test-Path $Path)) { return }
    $text = [IO.File]::ReadAllText($Path)
    $new  = [regex]::Replace($text, '(?s)[^\r\n]*claude-links:begin.*?claude-links:end[^\r\n]*\r?\n?', '')
    if ($new -ne $text) { [IO.File]::WriteAllText($Path, $new, $Utf8) }
  }

  $docs = [Environment]::GetFolderPath('MyDocuments')
  if (-not $docs) { $docs = Join-Path $HOME 'Documents' }
  Remove-ClBlock (Join-Path $CL 'CLAUDE.md')
  Remove-ClBlock (Join-Path $docs 'WindowsPowerShell\profile.ps1')
  Remove-ClBlock (Join-Path $docs 'PowerShell\profile.ps1')

  $S = Join-Path $CL 'settings.json'
  if (Test-Path $S) {
    try { $cfg = [IO.File]::ReadAllText($S) | ConvertFrom-Json } catch { $cfg = $null }
    if ($cfg -and $cfg.PSObject.Properties['hooks'] -and $cfg.hooks.PSObject.Properties['PostToolUse']) {
      Copy-Item $S "$S.bak" -Force
      $keep = @($cfg.hooks.PostToolUse | Where-Object {
        -not (@($_.hooks) | Where-Object { "$($_.command)" -match 'claude-links' })
      })
      if ($keep.Count -gt 0) { $cfg.hooks.PostToolUse = $keep }
      else { $cfg.hooks.PSObject.Properties.Remove('PostToolUse') }
      if (@($cfg.hooks.PSObject.Properties).Count -eq 0) { $cfg.PSObject.Properties.Remove('hooks') }
      [IO.File]::WriteAllText($S, ($cfg | ConvertTo-Json -Depth 20), $Utf8)
    }
  }

  Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $CL 'hooks\claude-links-log.ps1'), (Join-Path $CL 'recent-files')
  Write-Host 'Da go claude-links. Mo cua so PowerShell moi va khoi dong lai Claude Code.'
}
