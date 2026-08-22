---
name: obsidian-cli
description: Use when the user wants to interact with an Obsidian vault from the terminal — reading, creating, searching, or editing notes, managing tasks/tags/properties, or scripting vault automation.
---

# Obsidian CLI

Requires: Obsidian app **running** (auto-launches on first command).

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

## Gotchas

- Every command round-trips to the running app via IPC — fine for one-off scripts, **slow for bulk operations** on thousands of files (prefer direct file editing for that).
- `move`/`rename` require the destination extension for `move` (`to=folder/note.md`).
- Linux: may need a wrapper script in PATH before the system `obsidian` binary to avoid Electron flag injection issues; if run as a service, `PrivateTmp=false` is required for IPC.
- No CLI on mobile — desktop only.
