# Cascade block · canonical format

This file is the ONLY place the block's shape is defined. `session-start.ps1` injects it at
session start; `prompt-reminder.ps1` appends the skeleton below (between the two marker
comments) to every per-prompt reminder; `check-stop.ps1` enforces the mechanical rules.
Change the shape here and nowhere else.

## Part 1 · the opening block

### The four rows

| Row | Question it answers | Values |
|---|---|---|
| 🎯 GOAL | What is this turn for | Free text, one line |
| 💰 COST | What lands in my window, and roughly how big | Free text plus a size |
| 🤖 WHO | Where the heavy part is executed | One of `runner · workflow · file · me`, shown as `▸<pick>` only |
| 🔀 RUNS AS | How the work is arranged in time | One of `solo · parallel · sequential · pipeline`, shown as `▸<pick>` only |

WHO: `runner` = one or a few agents · `workflow` = 5+ agents, opt-in only ("use a workflow"
or "ultracode") · `file` = the payload lands on disk and only a path enters · `me` = self-execute.

RUNS AS: `solo` = one worker (me alone, or one runner) · `parallel` = 2+ runners, no order
between them · `sequential` = 2+ stages, one runner each · `pipeline` = 2+ stages, a stage may
hold 2+ runners. A validator is a gate, not a worker, so it never changes the shape.

### Rules

| # | Rule | Why |
|---|---|---|
| 1 | The whole block sits inside a ``` code fence, and the fence is the first thing in the reply | Outside a fence the desktop app joins the lines into one paragraph. The fence is what keeps the columns |
| 2 | No line over 56 characters | The desktop pane wraps around 60. A wrapped row breaks the column |
| 3 | One fact per row. A row that needs more text continues on the next line, indented to the value column | The eye scans down the label column; prose defeats that |
| 4 | Labels in a fixed column: marker, label, two spaces, value starting at column 13 | Alignment is the readability |
| 5 | A rule line separates the header from the tree | Two things to read, two zones |
| 6 | Every agent line: role, tag, task, and a "why <M>" of ≤8 words on the line below when the model is not the default for that role | The tag is the audit; the why is the reasoning |
| 7 | Never an em dash anywhere in the block. Use · or : | A deliberate style rule |
| 8 | WHO and RUNS AS show only the chosen value, prefixed ▸. Never print the other values in the block | The full legend proved confusing in use. The value lists live in the table above and in `reminder.md`, which the model sees under every prompt |
| 9 | Any runner at all gets a 🟪 Validator, drawn last in its group, with an ↩ line under it. The only block without one is REJECTED (WHO ▸me) | An independent check that shares no context with the maker |
| 10 | A validator runs one §9 model row above its maker, floor S-Med | Independence by model as well as by context; still cheap on small jobs |
| 11 | More than one stage: numbered stage rows `1.` `2.` in the tree, and every later stage says `starts when N passes` | Indentation is command, numbers are time |
| 12 | The ↩ line names what goes back, then `max 2`, then `↑` (move up one §9 row) | Loops are capped, and the cap is visible |

### Tree notation

```
numbers       = time     (1. runs before 2.)
indentation   = command  (who reports to whom)
🟪 last in a group = the gate on that group
↩             = loop: what goes back · max 2 · then ↑
"passes"      = a stage ends when its validator says so,
                not when its runners say so
```

A validator verdict splits two ways (doctrine §11). A **patch** (a few cells wrong, one invented
date) goes back to the same runner with the error list. A **failure** (wrong shape, invented
sections) gets a fresh runner with a new brief that includes the error list. Either way, two
rounds, then up one model row.

### Skeleton

<!-- skeleton:start -->
```
🟦 CASCADE DECISION
──────────────────────────────────────────────────────
🎯 GOAL     <one line, continue indented if needed>
💰 COST     <what lands in my window, roughly how big>
🤖 WHO      ▸<runner | workflow | file | me>
            <one line of detail>
🔀 RUNS AS  ▸<solo | parallel | sequential | pipeline>
──────────────────────────────────────────────────────
🟦 Orchestrator   [<M> · <Effort>]   you
├─ 🟥 Runner 1    [<M>-<Effort>]   <task>
│                           why <M>: <≤8 words>
└─ 🟪 Validator 1 [<M>-<Effort>]   <what it checks>
      ↩ fail: <what goes back> · max 2 · then ↑
```
```
🟧 CASCADE REJECTED · self-execute
──────────────────────────────────────────────────────
🎯 GOAL     <one line>
💰 COST     <nothing new | what, small>
🤖 WHO      ▸me
🔀 RUNS AS  ▸solo
```
<!-- skeleton:end -->

### Examples

Rejected, conversational (RUNS AS solo, WHO me):

```
🟧 CASCADE REJECTED · self-execute
──────────────────────────────────────────────────────
🎯 GOAL     Answer the restart question
💰 COST     nothing new
🤖 WHO      ▸me
🔀 RUNS AS  ▸solo
```

Solo, one runner (still gets a validator):

```
🟦 CASCADE DECISION
──────────────────────────────────────────────────────
🎯 GOAL     Find skills still calling a retired MCP
💰 COST     one ≤300-word list of paths and lines
🤖 WHO      ▸runner
            sweeps every SKILL.md in the tree
🔀 RUNS AS  ▸solo
──────────────────────────────────────────────────────
🟦 Orchestrator   [Opus · High]    you
├─ 🟥 Runner 1    [H-Low]   grep SKILL.md for the old MCP
│                           why H: pure pattern match
└─ 🟪 Validator 1 [S-Med]   every hit real, none missed
      ↩ fail: misses back to 1 · max 2 · then ↑
```

Parallel, three runners, one gate on the group:

```
🟦 CASCADE DECISION
──────────────────────────────────────────────────────
🎯 GOAL     Find which vendors have an overdue invoice
💰 COST     three ≤300-word returns + one verdict
🤖 WHO      ▸runner
            one runner per vendor, read its ledger
🔀 RUNS AS  ▸parallel
──────────────────────────────────────────────────────
🟦 Orchestrator   [Opus · High]    you
├─ 🟥 Runner 1    [H-Med]   vendor A · ledger
├─ 🟥 Runner 2    [H-Med]   vendor B · ledger
├─ 🟥 Runner 3    [H-Med]   vendor C · ledger
└─ 🟪 Validator 1 [O-XHigh] each verdict cites a line
      ↩ fail: uncited verdicts back · max 2 · then ↑
```

Sequential, two stages, a gate closes each:

```
🟦 CASCADE DECISION
──────────────────────────────────────────────────────
🎯 GOAL     Rebuild the registry to the new criteria,
            then have it audited independently
💰 COST     rewritten registry (~300 lines, I write it)
            + a ≤300-word audit verdict
🤖 WHO      ▸runner
            audit runner re-reads the file
🔀 RUNS AS  ▸sequential
──────────────────────────────────────────────────────
🟦 Orchestrator      [Opus · High]    you
├─ 1. rewrite        I write it, then it is gated
│  └─ 🟪 Validator 1 [O-XHigh] 8 criteria, no invention
│        ↩ fail: errors back to me · max 2
└─ 2. audit          starts when 1 passes
   ├─ 🟥 Runner 2    [S-Med]  audit v2 vs the criteria
   └─ 🟪 Validator 2 [O-XHigh] is the audit itself sound
         ↩ fail: fresh 2 with error list · max 2
```

Pipeline, two stages, a crowd inside stage 1:

```
🟦 CASCADE DECISION
──────────────────────────────────────────────────────
🎯 GOAL     Rebuild every project CLAUDE.md to the
            standard, then audit each one
💰 COST     two ≤300-word stage verdicts
🤖 WHO      ▸workflow
            2 stages, 3 runners, 2 validators
🔀 RUNS AS  ▸pipeline
──────────────────────────────────────────────────────
🟦 Orchestrator      [Opus · High]    you
├─ 1. rewrite        both runners together
│  ├─ 🟥 Runner 1a   [S-Med]  folders 1 to 6
│  ├─ 🟥 Runner 1b   [S-Med]  folders 7 to 13
│  └─ 🟪 Validator 1 [O-XHigh] schema filled, no
│                              invented facts
│        ↩ fail: errors to 1a/1b · max 2 · then ↑
└─ 2. audit          starts when 1 passes
   ├─ 🟥 Runner 2a   [S-Med]  check vs 8 criteria
   └─ 🟪 Validator 2 [O-XHigh] is the audit sound
         ↩ fail: fresh 2a with error list · max 2
```

Depth 2 with managers (tiers from doctrine §8 still apply; each manager gates its own group):

```
🟦 CASCADE DECISION
──────────────────────────────────────────────────────
🎯 GOAL     Build feature X: backend, frontend, tests
💰 COST     two ≤300-word manager returns
🤖 WHO      ▸workflow
            2 managers, 3 runners, 2 validators
🔀 RUNS AS  ▸parallel
──────────────────────────────────────────────────────
🟦 Orchestrator      [Opus · High]   you
├─ 🟩 Manager 1      [S-XHigh] backend
│  ├─ 🟥 Runner 1a   [H-Low]   schema grep
│  ├─ 🟥 Runner 1b   [S-Med]   write migrations
│  └─ 🟪 Validator 1 [O-XHigh] migrations apply clean
│        ↩ fail: errors to 1b · max 2 · then ↑
└─ 🟩 Manager 2      [S-XHigh] frontend
   ├─ 🟥 Runner 2a   [S-Med]   component pass
   └─ 🟪 Validator 2 [O-XHigh] renders, no console err
         ↩ fail: errors to 2a · max 2 · then ↑
```

## Part 2 · the closing pass (LANDING)

The opening block protects the model's context. The closing pass protects the user's
comprehension. It runs **silently, in thinking, before the last text block of every reply**, and
leaves **no stamp, no receipt, no mention**. Text written just
before a blocking question (`AskUserQuestion`) is a reply too. Plan mode is the only exemption.
The Stop hook logs a miss and shows nothing; the engine below is what prevents one.

### Add-only, never truncation

```
MAY                          MAY NEVER
───────────────────────────  ───────────────────────────
add a header                 delete a fact
add a table                  shorten for its own sake
add a bracket definition     merge two facts into one
add an example               drop a caveat/number/name
add spacing                  summarise a list away
split a long sentence        remove a jargon word
move the verdict to the top  tidy a detail away
```

The rule in one line, from the global CLAUDE.md: simplify the language, never the content.

### The four questions

| Question | What must be true | If not |
|---|---|---|
| Verdict first? | The first real sentence after the opening block is the answer | Move it up |
| Jargon defined? | Every technical term has a bracket definition on first use | Add the bracket |
| Walls? | No prose paragraph over ~4 rendered lines (300 characters) outside a fence | Break it into a table, list, or box |
| Dropped? | No fact, number, name, or caveat from the draft is missing from the final | Put it back |

### Headers, by reply size

Same thresholds as the engine tiers below, so there is one set of numbers to remember.

| Reply | Section titles |
|---|---|
| Under 150 words | None. One bold verdict line |
| 150 to 399 words | Bold lead lines, one per section |
| 400 words or more | `##` headers, each led by its emoji marker, a horizontal rule between sections, at most four |

### The engine · three tiers by draft size

| Draft | Steps | The user sees |
|---|---|---|
| Under 150 words | Answer the four questions in thinking, then print | The reply |
| 150 to 399 words | Write the draft to `<scratchpad>\draft.md` → run `%USERPROFILE%\.claude\cascade-hook\landing-check.ps1 -Path <that file>` → fix every MISS → re-run (max 2) → print | Two collapsed tool rows, then the reply |
| 400+ words, or any design or decision | The above, then spawn the 🟪 judge (below) on the draft → apply its fixes → re-run the script once → print | Three collapsed rows, then the reply |

Why tiers: the file step emits the reply's text twice (draft and final), so it costs about
double the reply's size in context, the one resource the cascade exists to protect. A one-line
answer drafted twice is waste; a 600-word design drafted twice is cheap insurance.

The judge is the closing gate, a fixed part of every long turn, and is **never drawn in the
cascade tree**: drawing it would make `WHO ▸me` vanish and empty the opening block of meaning.

### The judge

Sonnet · Med, fresh context, reads the draft file,
returns ≤300 words. It is a 🟪 gate on the reply, not a runner, so it needs no validator of its
own. The brief, copied with the path filled in:

```
[S-Med] Landing judge. Read <draft path>. The user's
comprehension is the only goal. Answer four questions,
with line references:
(1) Is the first real sentence after the opening block
    the answer?
(2) List every technical term. Which lack a bracket
    definition on first use?
(3) Any prose paragraph over ~4 rendered lines, or a
    comparison written as prose that should be a table?
(4) Anything that reads as dropped, vague, or hedged?
Return: verdict SEND or FIX, then the fixes as a
numbered list, one line each. No rewrite, no praise,
at most 300 words.
```

### Rules

| # | Rule | Why |
|---|---|---|
| 1 | The pass is silent. No stamp, no receipt, no "checked" line, no mention, and no miss ever reaches the user | The user wants the result, not the process |
| 2 | The pass runs last, over the finished draft | It is a pass over the draft, not a plan for it |
| 3 | Never an em dash anywhere in the reply | A deliberate style rule, machine-checked (L1) |
| 4 | `draft.md` lives in the session scratchpad, rewritten each time, never in a project folder and never under a cloud-synced drive folder | Same rule as `state.md` (doctrine §7) |
| 5 | The engine and the Stop hook share `landing-lib.ps1` | One definition of a wall, so the audit can never disagree with the engine |

### Example · a text wall, restructured

The moves, then the sample they produce. Invented scenario: the 6 AM Daily
Brief task failed three mornings and the user asked why.

| Move | In the sample |
|---|---|
| Verdict first, bold, jargon defined in brackets | the first line |
| A one-line map of what follows | "Three parts below..." |
| One emoji-led `##` header per part, a rule between parts | 🔍 🩹 ⚠️ |
| Evidence as a table, never as prose | the three log lines |
| One bold sentence per section, the rest plain | "The task was re-registered..." |
| The action in a fence, copyable and unmissable | the schtasks line |
| What the user does next as the last line, marked ▶️ | the closing line |
| Nothing dropped: every date, cause, fix, and leftover from the wall survives | the add-only rule above |

The wall it replaces began: "The scheduled task Daily Brief has failed on three consecutive
mornings, Monday the 7th through Wednesday the 9th, and after reading all three logs the
failure is identical each time: the collector script exits within two seconds with a
path-not-found error..." and ran 600 words without a break.

````
**The brief failed three mornings because the task
now runs as SYSTEM [the Windows service account,
which has no mapped network drive session]
and cannot see Z:. The fix is one command that you run,
changing the task's user back to you.**

Three parts below: what broke, the fix, what the
fix does not cover.

---

## 🔍 What broke

| Morning | Log line               | Meaning      |
|---|---|---|
| Mon 07  | path not found: Z:\... | Z: invisible |
| Tue 08  | same                   | same         |
| Wed 09  | same                   | same         |

**The task was re-registered on Sunday 06 by the
install script, which defaults to SYSTEM.** Windows
maps Z: per interactive user at login, so SYSTEM
never sees it. Before Sunday the task ran as your
account, which does.

---

## 🩹 The fix

One command, run by you, because it asks for your
Windows password and I never handle that:

```
schtasks /Change /TN "Daily Brief" /RU "%USERNAME%" /RP *
```

After it, the task runs as you again and Z: is
visible at 6 AM.

---

## ⚠️ What this does not fix

- **The install script still defaults to SYSTEM.**
  The next re-register brings this back. One-line
  change in install.ps1, on your go.
- **The three missed briefs.** Mon to Wed never ran.
  I can trigger the collector once for the 72-hour
  window so Thursday's brief is not missing anything.

▶️ **Next:** run the command above, then tell me. I
trigger the task once and read the log with you.
````

## Part 3 · between the block and the reply

Proven in the Claude desktop app, two live tests. Text written between tool calls
never reaches the user as written: a short line is dropped and the calls either side merge into
one collapsed row; a longer paragraph is rewritten by the app into a grey box in its own
words, em dash included. A four-sentence summary, asked for by name, reached the user only as
the app's two-sentence rewrite. Only two positions render verbatim: before the first tool
call, and after the last one.

### Rule

| Position | What goes there |
|---|---|
| After the block, before the first tool call | The plan. One line for a turn of one to three steps, else a numbered list |
| Between tool calls | Nothing. Not a word |
| After the last tool call | The reply. On a turn of four or more steps it opens with the verdict, then a "What happened" list, one line per step |

The plan says what is done, never who does it: the tree above it already shows that.
No 🟥 / 🟪 / "me" prefixes on plan lines.

### Skeleton

```
<opening block>

Plan
1. <what is done>
2. <what is done>
3. <what is done>
4. <what is done>

Ran N commands >            the app's collapsed row

**<verdict>**

What happened
1. <step: result>
2. <step: result>
3. <step: result>
4. <step: result>

<the rest of the reply>
```

### Why

The user wants the result, not the process, and every word they read should come from their own assistant.
The app's boxes paraphrase, add em dashes, and hide anything substantive written mid-turn.
Silence between tools is the only setting where nothing they read was written by the app.

## What the Stop checker tests

Mechanical facts only. Opening checks run on the FIRST assistant text after the last real
user prompt; closing checks run on the LAST assistant text after it. **Every check is
log-only**: a miss writes one deduped line to `compliance.log` and shows
nothing. Never blocks. A session-end routine can report the count.

Opening (unchanged):

1. The first non-empty line is a fence opener (```) and the line after it contains `CASCADE DECISION` or `CASCADE REJECTED`.
2. A line containing `GOAL` appears before the closing fence.

Closing, from `landing-lib.ps1`, the same code `landing-check.ps1` runs:

| # | Check on the last text block | Logged as |
|---|---|---|
| L1 | No em dash (U+2014) on any line outside a code fence | `Em dash in reply` |
| L2 | No prose paragraph over 300 characters outside a fence (table rows, headers, list items, and quotes are not prose) | `Text wall: N chars` |
| L3 | If the block has over 150 words outside fences, at least one line starts with `#`, `\|`, `- `, `* `, `N. `, or `>` | `No structure in a long reply` |

Anything else (widths, alignment, markers, validators, stages, the four questions, the judge)
is style, carried by this file and the reminder, not enforced.
