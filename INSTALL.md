# Cascade hook · install guide for Claude

This file is written for Claude Code. A user pasted a prompt asking you to install (or
uninstall) the Cascade hook from this folder. Follow these steps exactly, in order.

## Ground rules

- Never edit `settings.json` by hand. The bundled `cascade\install.ps1` does the edit, makes a
  backup, validates the result, and touches nothing but its own four hook entries.
- Never change the user's model, effort, permissions or any other setting. This package does
  not need any of that.
- If any step prints `ERROR`, stop, show the user the exact error lines, and do not retry with
  different flags unless they ask.
- Explain each step in plain words. The user may not be technical.

## Install

1. **Check the platform.** This package needs Windows with Windows PowerShell 5.1 (built into
   Windows 10 and 11). If you are not on Windows, stop and say so.

2. **Find the package.** The folder the user named must contain `cascade\install.ps1`. If it does
   not, ask the user where they unzipped it.

3. **Preview.** Run, from the package folder:

   ```
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\cascade\install.ps1 -WhatIf
   ```

   Show the user what it plans to do, in plain words:
   - it copies the hook files to `%USERPROFILE%\.claude\cascade-hook\`
   - it adds four hook entries to `%USERPROFILE%\.claude\settings.json`
   - it backs up `settings.json` first
   - nothing else changes

   If the preview shows a `WARNING` about another cascade hook, explain that an older copy
   seems to be wired in already and they would get duplicate reminders. Ask whether to continue.

4. **Ask for a clear yes.** Do not continue without one.

5. **Install.** Run the same command without `-WhatIf`. Tell the user the backup path it prints.

6. **Finish.** Tell the user:
   - start a **new** Claude Code session, because hooks load at session start;
   - in the new session, your first reply should open with a `CASCADE DECISION` or
     `CASCADE REJECTED` block. That is how they can tell it is working.
   - point them to the README's "What it costs" section.

## Uninstall

1. Run:

   ```
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.claude\cascade-hook\install.ps1" -Uninstall -WhatIf
   ```

   (If that path does not exist, use `.\cascade\install.ps1` from the package folder.)
2. Show the user what will be removed, and ask for a clear yes.
3. Run it again without `-WhatIf`.
4. Tell them: start a new session; the hook files are still in
   `%USERPROFILE%\.claude\cascade-hook\` (including their own `compliance.log`), and they can
   delete that folder themselves if they want them gone. Do not delete it for them unless they
   explicitly ask.

## Restore a backup

Each install or uninstall saves `settings.json.cascade-backup-<date-time>` next to
`settings.json`. To undo, the user can copy that file back over `settings.json`. Offer to do it
only if they ask, and show them which backup you would use first.
