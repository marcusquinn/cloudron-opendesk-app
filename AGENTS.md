# cloudron-opendesk-app

<!-- AI-CONTEXT-START -->

## Quick Reference

- **Build**: `# TODO: add build command`
- **Test**: `# TODO: add test command`
- **Deploy**: `# TODO: add deploy command`

## Project Overview

<!-- Brief description of what this project does and why it exists. -->

## Architecture

<!-- Key architectural decisions, tech stack, directory structure. -->

## Conventions

- Commits: [Conventional Commits](https://www.conventionalcommits.org/)
- Branches: `feature/`, `bugfix/`, `hotfix/`, `refactor/`, `chore/`
- Documentation: human/operator guides in `docs/`, AI-only context in `.agents/`;
  retain conventional root entrypoints and respect existing repository conventions.

## Key Files

| File | Purpose |
|------|---------|
| `.agents/AGENTS.md` | Project-specific agent instructions |
| `docs/` | Human/operator guides, linked from root entrypoints |
| `TODO.md` | Task tracking |
| `CHANGELOG.md` | Version history |

<!-- AI-CONTEXT-END -->

## Search targets

Search keywords, AI-answer questions and search entities live in `context/keywords.md` and `context/keywords/` (standard: `~/.aidevops/agents/seo/keywords-standard.md`). Read them, or run `aidevops keywords brief`, before naming, copy, metadata, schema, media, social or PR work. If the files are missing in a clone, run `aidevops keywords sync`.
