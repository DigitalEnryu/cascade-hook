# session-start.ps1 · SessionStart hook (matcher: startup|resume|clear|compact)
# Reads doctrine.md next to this script and injects it as SessionStart additionalContext.
# Windows PowerShell 5.1 only. Fails open: any error -> exit 0 with no harmful output.

try {
    # Read stdin as raw UTF-8 bytes (5.1's default stdin reader uses the OEM codepage
    # and mangles non-ASCII, e.g. emoji in the doctrine text).
    $stdinStream = [Console]::OpenStandardInput()
    $memoryStream = New-Object System.IO.MemoryStream
    $stdinStream.CopyTo($memoryStream)
    $inputBytes = $memoryStream.ToArray()
    $inputJson = [System.Text.Encoding]::UTF8.GetString($inputBytes)

    # Ensure stdout is written as UTF-8 so the doctrine text round-trips intact.
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    # stdin is parsed only to fail open gracefully if it is garbage; session-start does
    # not need any field out of it (doctrine.md path is $PSScriptRoot, not stdin-derived).
    if ($inputJson) {
        try { $null = $inputJson | ConvertFrom-Json } catch { }
    }

    $doctrinePath = Join-Path $PSScriptRoot 'doctrine.md'

    if (Test-Path -LiteralPath $doctrinePath -PathType Leaf) {
        $doctrineText = [System.IO.File]::ReadAllText($doctrinePath, [System.Text.Encoding]::UTF8)
    } else {
        $doctrineText = "[cascade-gate] doctrine.md missing in $doctrinePath; run install.ps1"
    }

    # format.md is the single source of the block's shape; inject it after the doctrine.
    $formatPath = Join-Path $PSScriptRoot 'format.md'
    if (Test-Path -LiteralPath $formatPath -PathType Leaf) {
        $formatText = [System.IO.File]::ReadAllText($formatPath, [System.Text.Encoding]::UTF8)
        $doctrineText = $doctrineText + "`n`n" + $formatText
    } else {
        $doctrineText = $doctrineText + "`n`n[cascade-gate] format.md missing in $formatPath; run install.ps1"
    }

    $output = [ordered]@{
        hookSpecificOutput = [ordered]@{
            hookEventName   = 'SessionStart'
            additionalContext = $doctrineText
        }
    }

    $json = $output | ConvertTo-Json -Compress -Depth 5
    Write-Output $json
    exit 0
} catch {
    # Fail open: never block session start, never leak error detail into context.
    exit 0
}
