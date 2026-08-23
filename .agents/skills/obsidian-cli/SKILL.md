---
name: obsidian-cli
description: Use when the user wants to interact with an Obsidian vault from the terminal — reading, creating, searching, or editing notes, managing tasks/tags/properties, or scripting vault automation. Requires Obsidian 1.12.7+ with CLI enabled and the app running.
---

# Obsidian CLI

Requires: Obsidian app **running** (auto-launches on first command) + CLI enabled in Settings → General.

## Core mechanics

- Syntax: `obsidian <command> param=value flag`. Quote values with spaces.
- No `file`/`path` given → defaults to the **active file**.
  - `file=Name` → resolves like a wikilink (name only, no extension needed).
  - `path=folder/note.md` → exact vault-relative path.
- `vault=<name>` targets a specific vault; must be the **first** parameter.
- `--copy` on any command copies output to clipboard.
- Multiline content: use `\n` (newline) and `\t` (tab) inside `content="..."`.
- Run bare `obsidian` to enter the TUI (autocomplete, history, `Ctrl+R` search).
- `obsidian help <command>` for full per-command docs.

## Most useful commands

**Notes**
```
obsidian read [file=/path=]                    # read a note (default: active)
obsidian create name=X content="..." template=T [open] [overwrite]
obsidian append file=X content="..."           # append to note
obsidian prepend file=X content="..."          # prepend after frontmatter
obsidian move file=X to=folder/new.md          # move/rename, updates links
obsidian rename file=X name=NewName
obsidian delete file=X [permanent]
```

**Daily notes**
```
obsidian daily                                 # open today's daily note
obsidian daily:read
obsidian daily:append content="- [ ] Task"
```

**Search**
```
obsidian search query="text" [path=folder] [limit=n] [format=json]
obsidian search:context query="text"           # grep-style path:line: text
```

**Tasks**
```
obsidian tasks [todo|done] [daily] [file=X] [format=json]
obsidian task file=X line=8 toggle             # toggle a task's status
obsidian task file=X line=8 done|todo
```

**Properties / tags / links**
```
obsidian property:set name=status value=done file=X
obsidian property:read name=status file=X
obsidian tags [counts] [sort=count]
obsidian backlinks file=X
obsidian unresolved                            # broken links in vault
```

**Vault / files**
```
obsidian vault info=name|path|files|folders|size
obsidian files [folder=X] [ext=md] [total]
obsidian file [file=X]                         # file metadata
```

## Safe content escaping (avoid GUI "syntax error" on create/append)

Symptom: `obsidian create path=X content=<long string>` fails or Obsidian shows a syntax/parse error, so the agent gives up and writes the file directly instead.

**Root cause is almost always the shell, not Obsidian.** The `content=` value passes through your shell before the CLI ever sees it. If the string contains unescaped `"`, literal newlines instead of `\n`, backticks, or `$`, the shell mangles or truncates the argument — Obsidian then receives malformed/partial content and errors on parsing it.

Checklist before sending long/complex `content=`:
- Use `\n` and `\t` escapes, never real line breaks, inside the quoted value.
- Escape every `"` in the content as `\"` (or switch outer quoting to single quotes if the shell allows it and the content has no single quotes).
- Escape or avoid literal `` ` `` and `$` (shell will otherwise try to execute/interpolate them).
- Escape backslashes (`\` → `\\`) before they collide with the CLI's own `\n`/`\t` escapes — this matters for Windows paths or LaTeX-like content.
- For large notes, prefer building the string programmatically (e.g. via a script that JSON/shell-escapes it) rather than hand-typing a long inline string.
- If content is too complex to escape reliably, split it: `create` with a short/empty body, then one or more `append` calls with smaller, individually-escaped chunks.
- As a last resort — not a first one — writing the file directly to disk is fine, but only after ruling out shell escaping as the cause; don't abandon the CLI on the first error.

**Known separate bug — payload size, not just escaping.** Independent of shell escaping, large `content=` values can crash the CLI's IPC layer with a JSON parse error even when perfectly escaped: reports show `create` succeeding at ~4KB of content but crashing past ~8KB, with the failure happening in Obsidian's main process before any vault/plugin code runs. If a long, correctly-escaped `create`/`append` still fails, don't assume it's your escaping — split the content into multiple smaller `append` calls (well under 4KB each) instead of one large `create`.

## Gotchas

- Every command round-trips to the running app via IPC — fine for one-off scripts, **slow for bulk operations** on thousands of files (prefer direct file editing for that).
- `move`/`rename` require the destination extension for `move` (`to=folder/note.md`).
- Linux: may need a wrapper script in PATH before the system `obsidian` binary to avoid Electron flag injection issues; if run as a service, `PrivateTmp=false` is required for IPC.
- No CLI on mobile — desktop only.
