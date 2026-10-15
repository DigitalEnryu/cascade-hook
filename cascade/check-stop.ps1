# check-stop.ps1 · Stop hook (no matcher)
# Skips silently in plan mode, on a re-entrant stop, or with no transcript. Otherwise
# finds the last real user prompt in the transcript, then the first assistant text block
# after it, and checks that block's first non-empty line opens with the cascade gate
# marker. It also takes the LAST assistant text block after that prompt
# and runs the three closing checks (em dash, text wall, structure) from landing-lib.ps1, the
# same code the pre-send engine landing-check.ps1 uses (see format.md Part 2).
# On a miss: one compliance.log line (deduped), nothing shown. Log-only.
# Windows PowerShell 5.1 only. Fails open: any parse error -> exit 0 silently.

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

    $permissionMode = $null
    if ($hookInput.PSObject.Properties.Name -contains 'permission_mode') {
        $permissionMode = $hookInput.permission_mode
    }
    if ($permissionMode -eq 'plan') { exit 0 }

    $stopHookActive = $false
    if ($hookInput.PSObject.Properties.Name -contains 'stop_hook_active') {
        $stopHookActive = $hookInput.stop_hook_active
    }
    if ($stopHookActive -eq $true) { exit 0 }

    $transcriptPath = $null
    if ($hookInput.PSObject.Properties.Name -contains 'transcript_path') {
        $transcriptPath = $hookInput.transcript_path
    }
    if (-not $transcriptPath) { exit 0 }
    if (-not (Test-Path -LiteralPath $transcriptPath -PathType Leaf)) { exit 0 }

    $sessionId = $null
    if ($hookInput.PSObject.Properties.Name -contains 'session_id') {
        $sessionId = $hookInput.session_id
    }

    # --- Parse the transcript JSONL, line by line, skipping any line that fails to parse. ---
    $lines = [System.IO.File]::ReadAllLines($transcriptPath, [System.Text.Encoding]::UTF8)

    $records = New-Object System.Collections.Generic.List[object]
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $rec = $line | ConvertFrom-Json
            $records.Add($rec)
        } catch {
            # malformed line: skip it, keep going
            continue
        }
    }

    if ($records.Count -eq 0) { exit 0 }

    # --- Find the LAST record that is a real user prompt. ---
    # Real prompt: type "user", and message.content is EITHER a plain STRING, OR an ARRAY of
    # content blocks that contains no "tool_result" block and at least one "text"/"image"
    # block (a prompt with a pasted screenshot or attachment - the user sends these often; a
    # tool_result continuation turn is also an array, but one made only of tool_result
    # blocks, which is what tells the two array shapes apart). Also not a sub-agent record
    # (isSidechain true), not a harness-injected companion record (isMeta true - e.g. an
    # image-caption line dropped mid-turn beside a tool_result), and not a harness-injected
    # wrapper (a <task-notification>, slash-command echo, or injected <system-reminder>
    # block) - the design's "return-line turns and task-notification turns are exempt".
    $injectedWrapperTags = @('task-notification', 'local-command-caveat', 'local-command-stdout', 'command-name', 'command-message', 'system-reminder')
    $injectedWrapperPattern = '^\s*<(' + ($injectedWrapperTags -join '|') + ')>'

    $lastUserIndex = -1
    for ($i = 0; $i -lt $records.Count; $i++) {
        $rec = $records[$i]

        $isSidechain = $false
        if ($rec.PSObject.Properties.Name -contains 'isSidechain') {
            $isSidechain = $rec.isSidechain
        }
        if ($isSidechain -eq $true) { continue }

        # Harness-injected companion record (e.g. an image-caption line dropped mid-turn
        # beside a tool_result), not a new message from the user. isMeta alone is NOT enough
        # to identify a wrapper turn (task-notifications carry isMeta:false), so this is an
        # ADDITIONAL skip on top of the tag-pattern check below, never a replacement for it.
        if (($rec.PSObject.Properties.Name -contains 'isMeta') -and ($rec.isMeta -eq $true)) { continue }

        if (-not ($rec.PSObject.Properties.Name -contains 'type')) { continue }
        if ($rec.type -ne 'user') { continue }

        if (-not ($rec.PSObject.Properties.Name -contains 'message')) { continue }
        $msg = $rec.message
        if (-not $msg) { continue }
        if (-not ($msg.PSObject.Properties.Name -contains 'content')) { continue }

        $content = $msg.content
        # A real prompt's content is either a plain string, or (any prompt the user sends
        # with a pasted screenshot/attachment) an ARRAY of content blocks (image/text). A
        # tool_result turn's content is also an array, but one made of tool_result blocks -
        # that is what distinguishes the two array shapes.
        if ($content -is [string]) {
            # Skip harness-injected wrappers: these are not a new message from the user.
            if ($content -match $injectedWrapperPattern) { continue }
            $lastUserIndex = $i
        } elseif ($content -is [array] -or $content -is [System.Collections.IEnumerable]) {
            $blocks = @($content)
            if ($blocks.Count -eq 0) { continue }

            $hasToolResult = $false
            $hasTextOrImage = $false
            $textParts = New-Object System.Collections.Generic.List[string]
            foreach ($block in $blocks) {
                if ($null -eq $block) { continue }
                if (-not ($block.PSObject.Properties.Name -contains 'type')) { continue }
                if ($block.type -eq 'tool_result') { $hasToolResult = $true }
                if ($block.type -eq 'image') { $hasTextOrImage = $true }
                if ($block.type -eq 'text') {
                    $hasTextOrImage = $true
                    if ($block.PSObject.Properties.Name -contains 'text') {
                        $textParts.Add([string]$block.text)
                    }
                }
            }

            # A real image/text prompt: no tool_result block, and at least one text or
            # image block. (Sampled safe on this workspace's transcripts: no array prompt
            # mixes tool_result with text/image.)
            if ((-not $hasToolResult) -and $hasTextOrImage) {
                $joinedText = [string]::Join(' ', $textParts.ToArray())
                # Skip harness-injected wrappers (e.g. an isMeta-less skill-preamble array):
                # test the joined text blocks, same pattern as the string-content case.
                if ($joinedText -and ($joinedText -match $injectedWrapperPattern)) { continue }
                $lastUserIndex = $i
            }
        }
    }

    if ($lastUserIndex -eq -1) { exit 0 }

    $userRecord = $records[$lastUserIndex]
    $userUuid = $null
    if ($userRecord.PSObject.Properties.Name -contains 'uuid') {
        $userUuid = $userRecord.uuid
    }

    # --- Find the FIRST and the LAST assistant text block after it. ---
    # First: the opening cascade block is checked there. Last: the closing LANDING stamp is
    # checked there (format.md Part 2).
    $assistantText = $null
    $lastAssistantText = $null
    for ($j = $lastUserIndex + 1; $j -lt $records.Count; $j++) {
        $rec = $records[$j]

        $isSidechain = $false
        if ($rec.PSObject.Properties.Name -contains 'isSidechain') {
            $isSidechain = $rec.isSidechain
        }
        if ($isSidechain -eq $true) { continue }

        if (-not ($rec.PSObject.Properties.Name -contains 'type')) { continue }
        if ($rec.type -ne 'assistant') { continue }

        if (-not ($rec.PSObject.Properties.Name -contains 'message')) { continue }
        $msg = $rec.message
        if (-not $msg) { continue }
        if (-not ($msg.PSObject.Properties.Name -contains 'content')) { continue }

        $content = $msg.content
        if (-not $content) { continue }

        # content is expected to be an array of content blocks. The first text block of the
        # first text-bearing record is the opening; the last text block of the last
        # text-bearing record is the closing. Keep scanning to the end for the latter.
        $recordFirstText = $null
        $recordLastText = $null
        foreach ($block in @($content)) {
            if ($null -eq $block) { continue }
            if (-not ($block.PSObject.Properties.Name -contains 'type')) { continue }
            if ($block.type -eq 'text') {
                if ($block.PSObject.Properties.Name -contains 'text') {
                    if ($null -eq $recordFirstText) { $recordFirstText = $block.text }
                    $recordLastText = $block.text
                }
            }
        }

        if ($null -ne $recordFirstText) {
            if ($null -eq $assistantText) { $assistantText = $recordFirstText }
            $lastAssistantText = $recordLastText
        }
    }

    # No assistant text found yet (e.g. Stop fired mid-turn before any text arrived): emit nothing.
    if ($null -eq $assistantText) { exit 0 }

    # --- Three mechanical checks on the first assistant text (shape lives in format.md): ---
    #   1. the header line carries the ASCII marker CASCADE DECISION|REJECTED
    #   2. that header sits inside a ``` fence that opens the reply (unfenced = text wall)
    #   3. a GOAL row appears before the closing fence
    $textLines = $assistantText -split "`r?`n"
    $nonEmpty = @($textLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($nonEmpty.Count -eq 0) { exit 0 }

    $marker = [regex]::new('^\s*\S*\s*CASCADE (DECISION|REJECTED)')
    $fence  = [regex]::new('^\s*```')
    $fenced = $fence.IsMatch($nonEmpty[0])
    if ($fenced -and $nonEmpty.Count -gt 1) { $headerLine = $nonEmpty[1] } else { $headerLine = $nonEmpty[0] }

    $reason = $null
    if (-not $marker.IsMatch($headerLine)) {
        $reason = 'Cascade gate missed'
    } elseif (-not $fenced) {
        $reason = 'Cascade block not fenced (renders as a text wall)'
    } else {
        $hasGoal = $false
        for ($i = 2; $i -lt $nonEmpty.Count; $i++) {
            if ($fence.IsMatch($nonEmpty[$i])) { break }
            if ($nonEmpty[$i] -match 'GOAL') { $hasGoal = $true; break }
        }
        if (-not $hasGoal) { $reason = 'Cascade block has no GOAL row' }
    }

    # --- Closing checks on the LAST assistant text (format.md Part 2, L1 to L3). ---
    # The three checks live in landing-lib.ps1, shared with landing-check.ps1, the pre-send
    # engine the model runs on its own draft. This is the after-the-fact audit of what was
    # actually sent. The LANDING pass itself (draft, check, fix, print) is the model's job.
    . (Join-Path $PSScriptRoot 'landing-lib.ps1')
    $closingReasons = (Get-LandingReport -Text $lastAssistantText).Reasons

    # The log excerpt names the block that failed: the opening block when it missed, else
    # the closing block.
    $excerptSource = $assistantText
    if ($null -eq $reason -and $closingReasons.Count -gt 0) { $excerptSource = $lastAssistantText }

    $reasons = New-Object System.Collections.Generic.List[string]
    if ($null -ne $reason) { $reasons.Add($reason) }
    foreach ($r in $closingReasons) { $reasons.Add($r) }
    if ($reasons.Count -eq 0) {
        # Hit on every check: emit nothing.
        exit 0
    }
    $reason = [string]::Join(' | ', $reasons.ToArray())

    # --- Miss: dedupe against compliance.log, append one line if new, emit nothing. ---
    $logPath = Join-Path $PSScriptRoot 'compliance.log'

    $first60 = $excerptSource
    if ($first60.Length -gt 60) { $first60 = $first60.Substring(0, 60) }
    # Single-line: collapse any embedded newlines/tabs in the excerpt.
    $first60 = ($first60 -replace '[\r\n\t]+', ' ').Trim()

    # Read/write compliance.log as UTF-8 without a BOM by hand (Add-Content -Encoding UTF8
    # in 5.1 writes a BOM on file creation, which would otherwise land as junk at the start
    # of a future reader's first line).
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    $alreadyLogged = $false
    if ((Test-Path -LiteralPath $logPath -PathType Leaf) -and $sessionId -and $userUuid) {
        $existingBytes = [System.IO.File]::ReadAllBytes($logPath)
        $existingText = $utf8NoBom.GetString($existingBytes)
        $existingLines = $existingText -split "`r?`n"
        foreach ($logLine in $existingLines) {
            if ($logLine -like "*`t$sessionId`t$userUuid`t*") {
                $alreadyLogged = $true
                break
            }
        }
    }

    if (-not $alreadyLogged) {
        $timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
        $logLine = "$timestamp`t$sessionId`t$userUuid`t$reason`t$first60`r`n"
        $logBytes = $utf8NoBom.GetBytes($logLine)
        $fileStream = [System.IO.File]::Open($logPath, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write)
        try {
            $fileStream.Write($logBytes, 0, $logBytes.Length)
        } finally {
            $fileStream.Close()
        }
    }

    # Log-only: no systemMessage. That message was user-facing (Claude Code
    # shows a Stop hook's systemMessage to the user and does not feed it back to the model),
    # and misses are deliberately never shown. compliance.log is the audit trail; a session-end routine
    # can report the count. Nothing is written to stdout on a miss.
    exit 0
} catch {
    exit 0
}
