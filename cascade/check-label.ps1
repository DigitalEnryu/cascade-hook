# check-label.ps1 · PreToolUse hook (matcher: Agent)
# Denies an Agent spawn whose tool_input.description does not open with a [M-Effort] tag,
# or whose tool_input.model / tool_input.effort disagree with that tag.
# Windows PowerShell 5.1 only. Fails open: any error -> exit 0 silently (never blocks a spawn
# on a parser bug; the gate is a nudge, not a wall).

try {
    $stdinStream = [Console]::OpenStandardInput()
    $memoryStream = New-Object System.IO.MemoryStream
    $stdinStream.CopyTo($memoryStream)
    $inputBytes = $memoryStream.ToArray()
    $inputJson = [System.Text.Encoding]::UTF8.GetString($inputBytes)

    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    if (-not $inputJson) { exit 0 }

    try {
        $hookInput = $inputJson | ConvertFrom-Json
    } catch {
        exit 0
    }

    $toolName = $null
    if ($hookInput.PSObject.Properties.Name -contains 'tool_name') {
        $toolName = $hookInput.tool_name
    }
    if ($toolName -ne 'Agent') { exit 0 }

    $description = $null
    $model = $null
    $effort = $null
    if ($hookInput.PSObject.Properties.Name -contains 'tool_input') {
        $toolInput = $hookInput.tool_input
        if ($toolInput) {
            $names = $toolInput.PSObject.Properties.Name
            if ($names -contains 'description') { $description = $toolInput.description }
            if ($names -contains 'model') { $model = $toolInput.model }
            if ($names -contains 'effort') { $effort = $toolInput.effort }
        }
    }
    if ($null -eq $description) { $description = '' }
    if ($model) { $model = ([string]$model).ToLowerInvariant() } else { $model = $null }
    if ($effort) { $effort = ([string]$effort).ToLowerInvariant() } else { $effort = $null }

    # The tag is an instruction, not a label. Without a model the agent
    # inherits Opus, so the tag must agree with the Agent tool's model and effort parameters.
    $tagRegex = [regex]::new('^\[([OSHF])-(Low|Med|High|XHigh|Max|Inh)\]\s')
    $match = $tagRegex.Match($description)

    $reason = $null
    if (-not $match.Success) {
        $reason = 'Agent description must start with a [M-Effort] tag, e.g. [S-Med] or [H-Low] (M in O/S/H/F, F only when the user asks; Effort in Low/Med/High/XHigh/Max/Inh). Re-issue the same spawn with the tag prefixed to the description, plus model and effort matching it.'
    } else {
        $letter = $match.Groups[1].Value
        $tier = $match.Groups[2].Value
        $modelMap = @{ 'O' = 'opus'; 'S' = 'sonnet'; 'H' = 'haiku'; 'F' = 'fable' }
        $effortMap = @{ 'Low' = 'low'; 'Med' = 'medium'; 'High' = 'high'; 'XHigh' = 'xhigh'; 'Max' = 'max' }
        $wantModel = $modelMap[$letter]
        $problems = New-Object System.Collections.Generic.List[string]

        $modelOk = ($model -eq $wantModel) -or ($letter -eq 'O' -and $null -eq $model)
        if (-not $modelOk) {
            $shown = if ($null -eq $model) { 'none (inherits Opus)' } else { "'$model'" }
            $problems.Add("tag [$letter-...] needs model '$wantModel', got $shown")
        }

        if ($tier -eq 'Inh') {
            if ($null -ne $effort) { $problems.Add("tag effort Inh means omit effort, got '$effort'") }
        } else {
            $wantEffort = $effortMap[$tier]
            if ($effort -ne $wantEffort) {
                $shown = if ($null -eq $effort) { 'none' } else { "'$effort'" }
                $problems.Add("tag effort $tier needs effort '$wantEffort', got $shown")
            }
        }

        if ($problems.Count -gt 0) {
            $reason = 'Agent model/effort disagree with the description tag: ' + ($problems -join '; ') + '. Re-issue the same spawn with model and effort set to match the tag (doctrine section 10), or retag it.'
        }
    }

    if ($null -eq $reason) { exit 0 }

    $output = [ordered]@{
        hookSpecificOutput = [ordered]@{
            hookEventName            = 'PreToolUse'
            permissionDecision       = 'deny'
            permissionDecisionReason = $reason
        }
    }

    $json = $output | ConvertTo-Json -Compress -Depth 5
    Write-Output $json
    exit 0
} catch {
    exit 0
}
