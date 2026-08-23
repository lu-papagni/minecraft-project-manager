# Project Guidelines

## Obsidian

- Project documentation lives in the dedicated obsidian vault. Use the `obsidian` CLI to access it.
- Notes must be written in a *wiki style*, with backlinks, references and tags.
- Always check if some information is already in Obsidian *before* starting a task; search by topic via tags before reading the whole note.
- Ask for confirmation before updating existing notes, except when brainstorming.
- Use mermaid when drawing diagrams.

### Special directories

- **Brainstorming**: put here all researches and notes taken while exploring ideas.

## Supabase / Database

This project uses [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) with declarative schema (`experimental.pgdelta.enabled = true`). The canonical schema lives in `supabase/schemas/`.

### npm commands

Read `package.json` for useful helper scripts.
