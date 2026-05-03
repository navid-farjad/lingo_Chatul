# ai-docs/

Long-form runbooks written for AI agents working on this codebase, not for
human operators. The deploy model is **user asks the agent → agent reads
these docs → agent executes** — so each doc here is concrete enough to be
followed step-by-step in a single session.

## Index

- [add-content.md](add-content.md) — how to add a new language deck or expand an existing one. Covers CSV format, the smoke → starter → full deck validation gate, voice config per language, and where to source words.

The deploy runbook lives at [../infra/DEPLOY.md](../infra/DEPLOY.md) since
it sits next to the deploy artifacts. The top-level project guide is
[../CLAUDE.md](../CLAUDE.md).
