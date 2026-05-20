#!/usr/bin/env bash
# Stop hook. Emits a desktop notification when the agent finishes a turn.
# -t auto-dismisses after 4s; -a tags the source so multiple notifs collapse.

cat >/dev/null
notify-send -a "fsh-agent" -t 4000 "fsh-agent" "Turn finished" 2>/dev/null || true
exit 0
