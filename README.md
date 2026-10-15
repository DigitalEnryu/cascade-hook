# Cascade hook for Claude Code

Created by Rueben Looi. MIT licensed.

A set of Claude Code hooks that make Claude **decide, out loud, how it will spend its context
before every reply**: what it will read itself, what it hands to helper agents, and which model
each helper runs on. Because it is enforced by hooks, not by a prompt you hope Claude remembers,
it fires every session.

Windows only (Windows PowerShell 5.1, built into Windows 10 and 11).

---

## What you get

| Part | What it does |
|---|---|
| **The cascade block** | Every reply opens with a short block: the goal, what enters context, who does the heavy work, and how the work is arranged. Agents are drawn as a tree, each with a model tag. |
| **The doctrine** | Loaded at session start. Rules for when to delegate, how much an agent may return (300 words), how to read files without flooding context, and which model fits which job. |
| **Model routing** | Haiku for mechanical and well-defined work, Sonnet for open extraction and supervising, Opus for judgement. Every helper agent gets an independent validator one step up. |
| **The label gate** | Blocks any helper agent whose description lacks a model tag like `[H-Low]`, or whose actual `model` / `effort` settings disagree with that tag. Claude fixes the tag and retries; your session never stops. |
| **The landing pass** | Before long replies go out, Claude checks its own draft: answer first, terms defined, no walls of text, no em dashes, nothing dropped. Replies of 400+ words also get a second opinion from a separate Sonnet agent. |
| **The miss log** | A Stop hook records, in a local file, any reply that skipped the block or broke the style checks. It never blocks and never shows you anything. |

---

## Install

You do not run any script yourself. Claude does it, shows you a preview, and asks first.

1. On GitHub, press **Code → Download ZIP**, and unzip it anywhere, for example your
   Downloads folder. You get a folder called `cascade-hook-main`.
2. Open Claude Code and paste this, with your real path:

   ```
   Install the Cascade hook from C:\Users\you\Downloads\cascade-hook-main. Read INSTALL.md in that folder and follow it exactly.
   ```

3. Claude previews the change, asks for a yes, installs, and tells you where the backup is.
4. Start a **new** Claude Code session. Your first reply should open with a `CASCADE DECISION`
   or `CASCADE REJECTED` block.

### What the install changes

- Copies the hook files to `%USERPROFILE%\.claude\cascade-hook\`.
- Adds four hook entries to `%USERPROFILE%\.claude\settings.json`, after saving a backup next
  to it (`settings.json.cascade-backup-<date-time>`).
- Nothing else. It does not change your model, effort, permissions or other hooks.

## Uninstall

Paste into Claude Code:

```
Uninstall the Cascade hook. Run powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.claude\cascade-hook\install.ps1" -Uninstall -WhatIf, show me what it will remove, and ask me before running it again without -WhatIf. Do not edit settings.json by hand.
```

Claude removes only this package's four hook entries (with a backup first). The files stay in
`%USERPROFILE%\.claude\cascade-hook\` until you delete that folder yourself.

---

## What it costs

Be aware of these before installing:

- **Context:** about 36 KB of instructions loads at the start of every session, and a short
  reminder is added under every prompt.
- **Helper agents:** the doctrine encourages delegating large reads and parallel work, and gives
  every helper a validator. Each extra agent starts with its own copy of the system prompt, so it
  costs tokens even for a small task.
- **Long replies:** replies of 400+ words spawn a Sonnet judge to check readability.
- **Permission prompts:** for replies of 150+ words Claude writes a draft file and runs a small
  PowerShell check, so you will see permission prompts for that unless you allow it.

If you would rather not pay for the landing pass, tell Claude in your own instructions to skip
it; the rest still works.

## Privacy

- The miss log (`compliance.log` in the hook folder) stores the time, session id, the reason,
  and the **first 60 characters** of a reply that missed a check. It stays on your machine.
  Nothing in this package sends anything anywhere.
- Do not commit or share your `compliance.log`. The `.gitignore` here excludes it.

## Good to know

- The label gate applies to every helper agent, including ones started by other skills or
  plugins. Claude adds the tag and retries automatically.
- The model tags map to Claude Code's model names: `O` opus, `S` sonnet, `H` haiku, `F` fable
  (used only when you ask for it).
- Hooks load at session start. After installing or uninstalling, start a new session.

## Files

| File | Role |
|---|---|
| `cascade/doctrine.md` | The rules, loaded at session start |
| `cascade/format.md` | The exact shape of the cascade block and the landing pass |
| `cascade/reminder.md`, `reminder-plan.md` | The short reminder added under each prompt (plan mode has its own) |
| `cascade/session-start.ps1` | Loads the doctrine and format at session start |
| `cascade/prompt-reminder.ps1` | Adds the reminder under each prompt |
| `cascade/check-label.ps1` | The label gate for helper agents |
| `cascade/check-stop.ps1` | Writes the miss log after each reply |
| `cascade/landing-lib.ps1`, `landing-check.ps1` | The shared checks for the landing pass |
| `cascade/install.ps1` | Install and uninstall, driven by Claude through `INSTALL.md` |
| `INSTALL.md` | Step-by-step guide Claude follows when you paste the install prompt |
