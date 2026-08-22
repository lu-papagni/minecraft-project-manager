# Project Guidelines

## Obsidian

- Project documentation lives in the dedicated obsidian vault. Use the `obsidian` CLI to access it.
- Notes must be written in a *wiki style*, with backlinks and references.
- Always check if some information is already in Obsidian before starting a web search.
- Ask for confirmation before updating existing notes, except when brainstorming.
- Use mermaid when drawing diagrams

### Special directories

- **Brainstorming**: put here all researches and notes taken while exploring ideas.

## Supabase / Database

This project uses [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) with declarative schema (`experimental.pgdelta.enabled = true`). The canonical schema lives in `supabase/schemas/`.

### Commands

Take a look at `package.json` for custom helper scripts.

- **Pull remote declarative schema** (overwrites `supabase/schemas/` from linked project `dsrrkfwtbjlymixfwmtc`, does not create migrations):
  ```bash
  npm run db:pull
  # equivalent to: npx supabase db pull --declarative --linked
  ```
- **Push local declarative schema to remote**:
  ```bash
  npm run db:push
  # equivalent to: npx supabase db push --linked
  ```
- **Generate fresh TypeScript types**:
  ```bash
  npm run db:types
  ```
