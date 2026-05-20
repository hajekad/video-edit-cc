#!/usr/bin/env bash
# Seeds /root/.claude from /opt/claude-config on every container start.
#
# CRITICAL — uses SYMLINKS for hooks/ and commands/, not copies. Reason:
# docker cp during a live session updates /opt/claude-config/, but if we
# install-copy at startup, the runtime path /root/.claude/ stays stale
# and the agent runs against pre-session versions of hooks/commands.
# Smoke test #2 hit exactly this: every harness hot-patch landed at /opt
# but never reached the agent because /root/.claude was copied once at
# container start. Symlinks make /opt → /root reflect instantly.
#
# The named /root/.claude volume retains session/history/credentials.
# settings.json / statusline.sh / scaffold-project.sh remain copies
# because the CLI may rewrite them.

set -e

SRC=/opt/claude-config
DST=/root/.claude

mkdir -p "$DST"

# Files that must remain copies (CLI may rewrite them).
install -m 0644 "$SRC/settings.json" "$DST/settings.json"
install -m 0755 "$SRC/statusline.sh" "$DST/statusline.sh"
install -m 0755 "$SRC/scaffold-project.sh" "$DST/scaffold-project.sh"

# Directories that must mirror /opt live — replace any existing copy
# with a fresh symlink on every container start.
for d in hooks commands; do
  if [ -L "$DST/$d" ]; then
    rm -f "$DST/$d"
  elif [ -d "$DST/$d" ]; then
    rm -rf "$DST/$d"
  fi
  ln -s "$SRC/$d" "$DST/$d"
done

# Self-extension scaffolding (see /docs/HARNESS_SELF_EXTENSION.md):
# /agents/fsh-tools/ — agent-authored tools live here, on PATH.
# /agents/fsh-hooks/ — agent-authored hooks live here, wired manually
#                     into settings.json when activated.
# Both bind-mounted from the host repo so they survive container
# restart AND image rebuild without any manifest dance.
mkdir -p /agents/fsh-tools /agents/fsh-hooks 2>/dev/null || true
# Place /agents/fsh-tools first on PATH so agent tools shadow baked
# ones if they ever conflict (intentional — local overrides the canonical).
export PATH="/agents/fsh-tools:$PATH"
# Persist the PATH addition for non-interactive shells the agent spawns.
if ! grep -q '/agents/fsh-tools' /etc/profile.d/fsh-paths.sh 2>/dev/null; then
  cat > /etc/profile.d/fsh-paths.sh <<'PROFILE_EOF'
# Added by seed.sh — see /docs/HARNESS_SELF_EXTENSION.md
export PATH="/agents/fsh-tools:$PATH"
PROFILE_EOF
  chmod 0644 /etc/profile.d/fsh-paths.sh
fi
# Same wiring inside the Claude Code Bash tool's non-login shell env.
if ! grep -q 'fsh-paths.sh' /root/.bashrc 2>/dev/null; then
  echo "[ -f /etc/profile.d/fsh-paths.sh ] && . /etc/profile.d/fsh-paths.sh" >> /root/.bashrc
fi

# Git safe-directory: /work + /agents are bind-mounted from the host repo
# and owned by the host user (uid mismatch with container root). The
# agent's auto-commit hook needs to operate on these without git's
# "dubious ownership" flag aborting commits.
git config --global --add safe.directory /work 2>/dev/null || true
git config --global --add safe.directory /agents 2>/dev/null || true
git config --global --add safe.directory '*' 2>/dev/null || true

exec "$@"
