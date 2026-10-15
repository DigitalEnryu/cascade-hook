# landing-lib.ps1 . shared closing checks (format.md Part 2, L1 to L3)
# Dot-sourced by check-stop.ps1 (the Stop hook, a log-only audit of what was actually sent)
# and by landing-check.ps1 (the pre-send engine the model runs on its own draft). One
# definition, so the audit and the engine can never disagree about what a wall is.
# Windows PowerShell 5.1 only. ASCII-only source: 5.1 reads an unmarked .ps1 in the system
# codepage, so a non-ASCII literal here would be mangled; such characters are built from
# code points instead.

function Get-LandingReport {
    param([string]$Text)
    # Returns an object with:
    #   Reasons         list of strings, empty = pass. Exact strings are what compliance.log carries.
    #   Words           words outside code fences
    #   LongestProse    characters in the longest prose paragraph outside fences (limit 300)
    #   EmDashes        count of U+2014 outside fences
    #   StructureLines  lines outside fences starting with a header, table, list, or quote marker
    #   ProseParagraphs count of prose paragraphs outside fences
    $fence = [regex]::new('^\s*```')
    $structureLine = [regex]::new('^\s*(#|\||- |\* |\d+\. |>)')
    $emDash = [string]([char]0x2014)

    $reasons = New-Object System.Collections.Generic.List[string]
    $result = [ordered]@{
        Reasons         = $reasons
        Words           = 0
        LongestProse    = 0
        EmDashes        = 0
        StructureLines  = 0
        ProseParagraphs = 0
    }
    if ([string]::IsNullOrWhiteSpace($Text)) { return [pscustomobject]$result }

    # Everything inside a ``` fence is exempt: the cascade block, code, boxes, tables drawn as art.
    $lines = $Text -split "`r?`n"
    $inFence = $false
    $outside = New-Object System.Collections.Generic.List[string]
    foreach ($ln in $lines) {
        if ($fence.IsMatch($ln)) { $inFence = -not $inFence; continue }
        if (-not $inFence) { $outside.Add($ln) }
    }

    $outsideText = [string]::Join("`n", $outside.ToArray())
    $result.EmDashes = ([regex]::Matches($outsideText, [regex]::Escape($emDash))).Count

    # A prose paragraph is a run of consecutive non-blank outside-fence lines in which no line
    # starts with a header, table, list, or quote marker. Its length is the sum of its lines;
    # 300 characters is about four rendered lines at the desktop pane's wrap.
    $words = 0
    $structure = 0
    $paraLen = 0
    $paraIsProse = $true
    $maxWall = 0
    $proseParas = 0
    foreach ($ln in $outside) {
        if ([string]::IsNullOrWhiteSpace($ln)) {
            if ($paraLen -gt 0 -and $paraIsProse) {
                $proseParas++
                if ($paraLen -gt $maxWall) { $maxWall = $paraLen }
            }
            $paraLen = 0
            $paraIsProse = $true
            continue
        }
        $words += @($ln -split '\s+' | Where-Object { $_ -ne '' }).Count
        if ($structureLine.IsMatch($ln)) { $structure++; $paraIsProse = $false }
        $paraLen += $ln.Length
    }
    if ($paraLen -gt 0 -and $paraIsProse) {
        $proseParas++
        if ($paraLen -gt $maxWall) { $maxWall = $paraLen }
    }

    $result.Words = $words
    $result.LongestProse = $maxWall
    $result.StructureLines = $structure
    $result.ProseParagraphs = $proseParas

    # L1 to L3. Keep these strings stable: compliance.log lines and any reader depend on them.
    if ($result.EmDashes -gt 0) { $reasons.Add('Em dash in reply') }
    if ($maxWall -gt 300) { $reasons.Add("Text wall: $maxWall chars") }
    if ($words -gt 150 -and $structure -eq 0) { $reasons.Add('No structure in a long reply') }

    return [pscustomobject]$result
}
