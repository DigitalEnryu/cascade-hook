# landing-check.ps1 . the pre-send engine (format.md Part 2)
# The model writes its draft reply to a file in the session scratchpad, runs this on it, fixes
# whatever it reports, re-runs (max 2), and prints only a draft that passes. Same three checks
# as the Stop hook, taken from landing-lib.ps1, so the after-the-fact audit can never disagree
# with the engine. The user never sees the draft, the report, or a miss: only the final reply.
#
# Usage:   powershell -NoProfile -ExecutionPolicy Bypass -File landing-check.ps1 -Path <draft.md>
# Output:  PASS or MISS: <reasons>, one line of counts, one TIER line. Always exit 0.
# Windows PowerShell 5.1 only. ASCII-only source (see landing-lib.ps1 for why).
param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    . (Join-Path $PSScriptRoot 'landing-lib.ps1')

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Output "MISS: draft not found at $Path"
        exit 0
    }

    $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $r = Get-LandingReport -Text $text

    if ($r.Reasons.Count -eq 0) {
        Write-Output 'PASS'
    } else {
        Write-Output ('MISS: ' + [string]::Join(' | ', $r.Reasons.ToArray()))
    }
    Write-Output ("words {0} | longest prose paragraph {1} chars (limit 300) | em dashes {2} | structure lines {3} | prose paragraphs {4}" -f $r.Words, $r.LongestProse, $r.EmDashes, $r.StructureLines, $r.ProseParagraphs)

    # Tier hint (format.md Part 2): the script runs from 150 words; the judge joins from 400
    # words or on any design or decision, which only the model can recognise.
    if ($r.Words -ge 400) {
        Write-Output 'TIER: judge. 400+ words: spawn the [S-Med] landing judge on this draft before printing'
    } elseif ($r.Words -ge 150) {
        Write-Output 'TIER: script. 150 to 399 words: fix every MISS, re-run, then print (judge only if this is a design or decision)'
    } else {
        Write-Output 'TIER: thinking. Under 150 words: the file step was optional'
    }
    exit 0
} catch {
    Write-Output ('MISS: landing-check error: ' + $_.Exception.Message)
    exit 0
}
