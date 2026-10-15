<#
.SYNOPSIS
    Installs or removes the Cascade hook for Claude Code (Windows PowerShell 5.1).

.DESCRIPTION
    Install:
      1. Copies the hook files from this folder to the install folder
         (default %USERPROFILE%\.claude\cascade-hook\) and checks every file arrived.
      2. Backs up settings.json next to itself (settings.json.cascade-backup-<time>).
      3. Adds exactly four hook entries to settings.json (SessionStart, UserPromptSubmit,
         PreToolUse matcher Agent, Stop). Every other key and every other hook is left
         untouched. It never changes your model, effort, permissions, or anything else.
      4. Writes to a temporary file, validates it, then swaps it in, and re-reads the
         result to confirm the four entries are present.

    Uninstall (-Uninstall): removes only the hook entries whose command points into the
    install folder, with the same backup and validation. It does not delete any files; it
    prints the folder so you can remove it yourself.

    An entry is "ours" only if its command contains the install folder path. Hooks from
    any other tool are never touched, even if they share a matcher group.

.PARAMETER WhatIf
    Print what would change. Copies nothing and writes nothing.

.PARAMETER Uninstall
    Remove this package's hook entries instead of adding them.

.PARAMETER SettingsPath
    The settings.json to edit. Default: %USERPROFILE%\.claude\settings.json

.PARAMETER InstallDir
    Where the hook files live. Default: %USERPROFILE%\.claude\cascade-hook

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -WhatIf
#>

param(
    [switch]$WhatIf,
    [switch]$Uninstall,
    [string]$SettingsPath = (Join-Path $env:USERPROFILE '.claude\settings.json'),
    [string]$InstallDir = (Join-Path $env:USERPROFILE '.claude\cascade-hook')
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$tag = '[cascade-hook]'

function Get-Prop {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    if ($Object.PSObject.Properties.Name -contains $Name) { return $Object.$Name }
    return $null
}

function Set-Prop {
    param($Object, [string]$Name, $Value)
    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
}

function Read-JsonFile {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $text = $utf8NoBom.GetString($bytes, 3, $bytes.Length - 3)
    } else {
        $text = $utf8NoBom.GetString($bytes)
    }
    if ($text.Trim().Length -eq 0) { return (New-Object PSCustomObject) }
    return ($text | ConvertFrom-Json)
}

function Get-AllCommands {
    param($SettingsObj)
    $found = New-Object System.Collections.Generic.List[string]
    $h = Get-Prop $SettingsObj 'hooks'
    if ($h) {
        foreach ($ev in $h.PSObject.Properties.Name) {
            foreach ($group in @(Get-Prop $h $ev)) {
                foreach ($entry in @(Get-Prop $group 'hooks')) {
                    $cmd = Get-Prop $entry 'command'
                    if ($cmd) { $found.Add([string]$cmd) }
                }
            }
        }
    }
    return ,$found
}

# --- paths and ownership --------------------------------------------------------------

$InstallDir = [System.IO.Path]::GetFullPath($InstallDir)
$installDirFwd = $InstallDir -replace '\\', '/'
$ownMarker = ($installDirFwd.TrimEnd('/') + '/').ToLowerInvariant()

function Test-Ours {
    param([string]$Command)
    if (-not $Command) { return $false }
    return (($Command -replace '\\', '/').ToLowerInvariant().Contains($ownMarker))
}

$packageFiles = @(
    'doctrine.md', 'format.md', 'reminder.md', 'reminder-plan.md',
    'session-start.ps1', 'prompt-reminder.ps1', 'check-stop.ps1', 'check-label.ps1',
    'landing-lib.ps1', 'landing-check.ps1', 'install.ps1'
)

$hookDefs = @(
    [ordered]@{ Event = 'SessionStart';     Matcher = 'startup|resume|clear|compact'; Script = 'session-start.ps1' },
    [ordered]@{ Event = 'UserPromptSubmit'; Matcher = $null;                         Script = 'prompt-reminder.ps1' },
    [ordered]@{ Event = 'PreToolUse';       Matcher = 'Agent';                       Script = 'check-label.ps1' },
    [ordered]@{ Event = 'Stop';             Matcher = $null;                         Script = 'check-stop.ps1' }
)

$changes = New-Object System.Collections.Generic.List[string]
$mode = if ($Uninstall) { 'uninstall' } else { 'install' }
Write-Host "$tag Mode: $mode$(if ($WhatIf) { ' (preview only, nothing is changed)' })"
Write-Host "$tag Settings file: $SettingsPath"
Write-Host "$tag Hook folder:   $InstallDir"

try {
    # --- 1. files ---------------------------------------------------------------------
    if (-not $Uninstall) {
        $sourceDir = [System.IO.Path]::GetFullPath($PSScriptRoot)
        $missingSource = @($packageFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $sourceDir $_) -PathType Leaf) })
        if ($missingSource.Count -gt 0) {
            Write-Host "$tag ERROR: these package files are missing next to install.ps1: $($missingSource -join ', ')"
            Write-Host "$tag Nothing was changed. Re-download the package and try again."
            exit 1
        }
        if ($sourceDir.TrimEnd('\') -ieq $InstallDir.TrimEnd('\')) {
            $changes.Add('Files: already in the hook folder (no copy needed)')
        } else {
            $changes.Add("Files: copy $($packageFiles.Count) files to $InstallDir")
            if (-not $WhatIf) {
                New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
                foreach ($f in $packageFiles) {
                    Copy-Item -LiteralPath (Join-Path $sourceDir $f) -Destination (Join-Path $InstallDir $f) -Force
                }
                $missingTarget = @($packageFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $InstallDir $_) -PathType Leaf) })
                if ($missingTarget.Count -gt 0) {
                    Write-Host "$tag ERROR: copy failed for: $($missingTarget -join ', '). settings.json was NOT changed."
                    exit 1
                }
            }
        }
    }

    # --- 2. read settings -------------------------------------------------------------
    $settingsExisted = Test-Path -LiteralPath $SettingsPath -PathType Leaf
    if ($settingsExisted) {
        try {
            $settings = Read-JsonFile $SettingsPath
        } catch {
            Write-Host "$tag ERROR: $SettingsPath is not valid JSON, so it was left exactly as it is."
            Write-Host "$tag Fix or restore that file, then run again. Parser said: $($_.Exception.Message)"
            exit 1
        }
        if ($null -eq $settings) { $settings = New-Object PSCustomObject }
    } else {
        if ($Uninstall) {
            Write-Host "$tag No settings file found, so there is nothing to uninstall."
            exit 0
        }
        $settings = New-Object PSCustomObject
        $changes.Add('settings.json: does not exist yet, a new one will be created')
    }

    $hooksObj = Get-Prop $settings 'hooks'
    if ($null -eq $hooksObj) {
        $hooksObj = New-Object PSCustomObject
        if (-not $Uninstall) { Set-Prop $settings 'hooks' $hooksObj }
    }

    # --- 3. remove our old entries, never anyone else's ------------------------------
    $removed = 0
    foreach ($ev in @($hooksObj.PSObject.Properties.Name | Where-Object { $_ })) {
        $newGroups = New-Object System.Collections.Generic.List[object]
        foreach ($group in @(Get-Prop $hooksObj $ev)) {
            $entries = @(Get-Prop $group 'hooks')
            $keep = @($entries | Where-Object { -not (Test-Ours (Get-Prop $_ 'command')) })
            $removed += ($entries.Count - $keep.Count)
            if ($keep.Count -eq $entries.Count) {
                $newGroups.Add($group)
            } elseif ($keep.Count -gt 0) {
                Set-Prop $group 'hooks' ([object[]]$keep)
                $newGroups.Add($group)
            }
        }
        if ($newGroups.Count -gt 0) {
            Set-Prop $hooksObj $ev ([object[]]$newGroups.ToArray())
        } else {
            $hooksObj.PSObject.Properties.Remove($ev)
        }
    }
    if ($removed -gt 0) { $changes.Add("Removed $removed existing cascade-hook entr$(if ($removed -eq 1) { 'y' } else { 'ies' })") }

    # --- 4. add ours (install only) ----------------------------------------------------
    $expected = New-Object System.Collections.Generic.List[string]
    if (-not $Uninstall) {
        foreach ($def in $hookDefs) {
            $cmd = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $installDirFwd + '/' + $def.Script + '"'
            $expected.Add($cmd)
            $entry = New-Object PSCustomObject
            Set-Prop $entry 'type' 'command'
            Set-Prop $entry 'command' $cmd
            $group = New-Object PSCustomObject
            if ($def.Matcher) { Set-Prop $group 'matcher' $def.Matcher }
            Set-Prop $group 'hooks' ([object[]]@($entry))
            $existing = @(Get-Prop $hooksObj $def.Event | Where-Object { $null -ne $_ })
            Set-Prop $hooksObj $def.Event ([object[]]($existing + $group))
            $changes.Add("Add $($def.Event) hook -> $($def.Script)")
        }

        # Warn (never act) if another copy of a cascade hook is already wired.
        $others = @((Get-AllCommands $settings) | Where-Object { ($_ -match 'cascade') -and -not (Test-Ours $_) })
        if ($others.Count -gt 0) {
            $changes.Add("WARNING: $($others.Count) other hook command(s) mention 'cascade'. If that is an older copy, you will get duplicate reminders. They were NOT changed:")
            foreach ($o in $others) { $changes.Add("    $o") }
        }
    }

    foreach ($c in $changes) { Write-Host "  - $c" }
    if ($Uninstall -and $removed -eq 0) {
        Write-Host "$tag No cascade-hook entries found. Nothing to change."
        exit 0
    }
    if ($WhatIf) {
        Write-Host "$tag Preview only: nothing was copied or written."
        exit 0
    }

    # --- 5. backup, write to temp, validate, swap in ----------------------------------
    $settingsDir = Split-Path -Parent $SettingsPath
    if (-not (Test-Path -LiteralPath $settingsDir)) { New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null }
    if ($settingsExisted) {
        $backup = $SettingsPath + '.cascade-backup-' + (Get-Date).ToString('yyyyMMdd-HHmmss')
        Copy-Item -LiteralPath $SettingsPath -Destination $backup -Force
        Write-Host "$tag Backup saved: $backup"
    }

    $json = $settings | ConvertTo-Json -Depth 32
    $tmp = $SettingsPath + '.cascade-tmp'
    [System.IO.File]::WriteAllText($tmp, $json, $utf8NoBom)
    $check = Read-JsonFile $tmp
    if ($null -eq $check) { throw 'temporary file did not parse back' }
    if ($settingsExisted) {
        try {
            # [NullString]::Value, not $null: PowerShell turns $null into "" for a string
            # argument, which File.Replace rejects as an illegal path.
            [System.IO.File]::Replace($tmp, $SettingsPath, [NullString]::Value)
        } catch {
            # Some file systems do not support Replace; the backup above still protects the user.
            Copy-Item -LiteralPath $tmp -Destination $SettingsPath -Force
            Remove-Item -LiteralPath $tmp -Force
        }
    } else {
        Move-Item -LiteralPath $tmp -Destination $SettingsPath -Force
    }

    # --- 6. verify the file on disk ----------------------------------------------------
    $final = Get-AllCommands (Read-JsonFile $SettingsPath)
    if ($Uninstall) {
        $left = @($final | Where-Object { Test-Ours $_ })
        if ($left.Count -gt 0) { Write-Host "$tag ERROR: $($left.Count) entries still present after uninstall."; exit 1 }
        Write-Host "$tag Removed. Start a new Claude Code session to finish."
        Write-Host "$tag The hook files are still in $InstallDir (including your compliance.log). Delete that folder yourself if you no longer want them."
    } else {
        $missing = @($expected | Where-Object { $final -notcontains $_ })
        if ($missing.Count -gt 0) {
            Write-Host "$tag ERROR: the written file is missing $($missing.Count) expected entries. Restore the backup above."
            exit 1
        }
        Write-Host "$tag Installed. Start a new Claude Code session to load it."
    }
    exit 0
} catch {
    Write-Host "$tag ERROR: $($_.Exception.Message)"
    if ($tmp -and (Test-Path -LiteralPath $tmp)) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    Write-Host "$tag settings.json was not replaced. If a backup was printed above, it is your untouched original."
    exit 1
}
