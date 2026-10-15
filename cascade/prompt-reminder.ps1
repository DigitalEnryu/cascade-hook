# prompt-reminder.ps1 · UserPromptSubmit hook (no matcher)
# Prints reminder.md (or reminder-plan.md when permission_mode is "plan") to stdout as
# plain text; UserPromptSubmit's plain stdout on exit 0 is injected into context.
# Windows PowerShell 5.1 only. Fails open: any error -> exit 0 with no harmful output.

try {
    $stdinStream = [Console]::OpenStandardInput()
    $memoryStream = New-Object System.IO.MemoryStream
    $stdinStream.CopyTo($memoryStream)
    $inputBytes = $memoryStream.ToArray()
    $inputJson = [System.Text.Encoding]::UTF8.GetString($inputBytes)

    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    $permissionMode = $null
    if ($inputJson) {
        try {
            $parsed = $inputJson | ConvertFrom-Json
            if ($parsed -and $parsed.PSObject.Properties.Name -contains 'permission_mode') {
                $permissionMode = $parsed.permission_mode
            }
        } catch { }
    }

    if ($permissionMode -eq 'plan') {
        $reminderPath = Join-Path $PSScriptRoot 'reminder-plan.md'
    } else {
        $reminderPath = Join-Path $PSScriptRoot 'reminder.md'
    }

    if (Test-Path -LiteralPath $reminderPath -PathType Leaf) {
        $reminderText = [System.IO.File]::ReadAllText($reminderPath, [System.Text.Encoding]::UTF8)
        Write-Output $reminderText
    } else {
        Write-Output '[cascade-gate] reminder file missing'
    }

    # Outside plan mode, append the block skeleton extracted from format.md (the single
    # source of the block's shape) so the reminder can never drift from that file. (A second
    # marked block for a closing stamp existed for a while and was removed by design.)
    if ($permissionMode -ne 'plan') {
        $formatPath = Join-Path $PSScriptRoot 'format.md'
        if (Test-Path -LiteralPath $formatPath -PathType Leaf) {
            $formatText = [System.IO.File]::ReadAllText($formatPath, [System.Text.Encoding]::UTF8)
            $startTag = '<!-- skeleton:start -->'
            $endTag = '<!-- skeleton:end -->'
            $s = $formatText.IndexOf($startTag)
            $e = $formatText.IndexOf($endTag)
            if ($s -ge 0 -and $e -gt $s) {
                $skeleton = $formatText.Substring($s + $startTag.Length, $e - $s - $startTag.Length).Trim()
                Write-Output 'Shape (copy it; full rules in format.md, already in context):'
                Write-Output $skeleton
            }
        }
    }

    exit 0
} catch {
    exit 0
}
