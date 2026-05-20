# AGENTS.md — FotoStudioH

This file is a pointer for non-Claude-Code agents (Codex, OpenClaw,
Hermes, etc.) that read `AGENTS.md` by convention.

The real operating rules live in **[CLAUDE.md](./CLAUDE.md)** alongside
this file. Everything in there applies equally to a Codex (or other-
agent) session — the only difference is sub-agent dispatch syntax.

## Sub-agent dispatch — agent-runtime equivalents

When CLAUDE.md says "spawn an in-instance Agent (subagent_type:
general-purpose)", the equivalent in other runtimes:

- **Codex** — use the `dispatch` tool with the prompt verbatim.
- **OpenClaw** — `subagent_invoke` with the same prompt shape.
- **Hermes** — `delegate_subtask`.

The prompt content does not change. The reviewer-gate protocol, the
parallel-overlay pattern, and the editor-sub-agent EDL brief all work
across runtimes — only the call shape differs.

## Skill-registration equivalents

`agents/video-use/install.md` lists per-runtime symlink targets:

- Claude Code: `~/.claude/skills/<name>`
- Codex: `${CODEX_HOME:-~/.codex}/skills/<name>`
- Hermes / OpenClaw: their own skills dir; or import via system prompt

The container's `/agents/` bind-mount makes every cloned repo
available regardless of runtime; per-runtime skill registration is
optional convenience.

## Continuous-worker loop

The Stop-hook chain (auto-commit → loop-not-done → notify-stop) is
runtime-agnostic — it only cares about `Stop` hook firing, which
every major agentic CLI supports. The hook scripts are plain bash
under `/opt/claude-config/hooks/`.

For Codex specifically: confirm `~/.codex/config.toml` has hooks
enabled. The seed pattern in `/opt/claude-config/seed.sh` only
upserts into `/root/.claude/`; Codex would need its own install path.
The smoke test surfaces this if it's an issue.
