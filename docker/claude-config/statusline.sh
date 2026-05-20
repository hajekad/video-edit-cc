#!/usr/bin/env bash
# Status line. Reads stdin JSON from Claude Code; uses server-provided
# rate_limits and context_window fields rather than estimating locally.
#
# Leads with a project label (CLAUDE_PROJECT_LABEL env, falls back to $HOSTNAME)
# so it's unambiguous which container/project the agent is operating in.

INPUT=$(cat)

TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')
CWD=$(       printf '%s' "$INPUT" | jq -r '.cwd // .workspace.current_dir // empty')
DIM=$'\033[2m'; RESET=$'\033[0m'

# ── Project label ────────────────────────────────────────────────────
# Source order: CLAUDE_PROJECT_LABEL env → /root/.claude/.project-label
# file → $HOSTNAME (random container ID if not started with --hostname).
LABEL="${CLAUDE_PROJECT_LABEL:-}"
[ -z "$LABEL" ] && [ -r /root/.claude/.project-label ] && LABEL=$(cat /root/.claude/.project-label)
[ -z "$LABEL" ] && LABEL="${HOSTNAME:-unknown}"
printf '\033[1;45;97m %s \033[0m  ' "$LABEL"

# ── 5-hour quota bar (server-authoritative) ──────────────────────────
# .rate_limits.five_hour is populated by the harness from API rate-limit
# headers. Absent on first turn / non-subscribers; show a placeholder then.
read -r PCT_RAW RESETS_AT <<<"$(printf '%s' "$INPUT" | jq -r '
  .rate_limits.five_hour
  | if . then "\(.used_percentage) \(.resets_at)" else "- -" end
')"

if [ "$PCT_RAW" = "-" ]; then
  printf '%s[no quota data yet]%s' "$DIM" "$RESET"
else
  PCT=${PCT_RAW%.*}; [ -z "$PCT" ] || [ "$PCT" = "null" ] && PCT=0
  [ "$PCT" -gt 100 ] && PCT=100

  BAR_LEN=20
  FILLED=$((PCT * BAR_LEN / 100))
  [ "$FILLED" -gt "$BAR_LEN" ] && FILLED=$BAR_LEN
  EMPTY=$((BAR_LEN - FILLED))

  BAR=""
  i=0; while [ "$i" -lt "$FILLED" ]; do BAR="${BAR}█"; i=$((i+1)); done
  i=0; while [ "$i" -lt "$EMPTY"  ]; do BAR="${BAR}░"; i=$((i+1)); done

  NOW=$(date -u +%s)
  REMAINING=$((RESETS_AT - NOW))
  if [ "$REMAINING" -le 0 ]; then
    TIME_STR="reset due"
  else
    H=$((REMAINING / 3600))
    M=$(((REMAINING % 3600) / 60))
    TIME_STR=$(printf 'resets in %dh %02dm' "$H" "$M")
  fi

  if   [ "$PCT" -lt 50 ]; then COLOR=$'\033[32m'
  elif [ "$PCT" -lt 80 ]; then COLOR=$'\033[33m'
  else                          COLOR=$'\033[31m'
  fi

  printf '%s[%s]%s %3d%% %s•%s %s' \
    "$COLOR" "$BAR" "$RESET" "$PCT" "$DIM" "$RESET" "$TIME_STR"
fi

# ── 7-day weekly limit (compact) ─────────────────────────────────────
WEEK=$(printf '%s' "$INPUT" | jq -r '.rate_limits.seven_day.used_percentage // empty')
if [ -n "$WEEK" ]; then
  WEEK=${WEEK%.*}; [ -z "$WEEK" ] && WEEK=0
  if   [ "$WEEK" -lt 50 ]; then WCOLOR=$'\033[32m'
  elif [ "$WEEK" -lt 80 ]; then WCOLOR=$'\033[33m'
  else                          WCOLOR=$'\033[31m'
  fi
  printf '  %s┃%s  %s7d %d%%%s' "$DIM" "$RESET" "$WCOLOR" "$WEEK" "$RESET"
fi

# ── Conversation tokens (cumulative, from stdin) ─────────────────────
CONVO=$(printf '%s' "$INPUT" | jq -r '
  (.context_window.total_input_tokens  // 0) +
  (.context_window.total_output_tokens // 0)')
CONVO=${CONVO:-0}

if [ "$CONVO" -gt 0 ]; then
  if   [ "$CONVO" -lt 1000 ];     then NUM=$(printf '%d tok'      "$CONVO")
  elif [ "$CONVO" -lt 1000000 ];  then NUM=$(printf '%dK tok'     $((CONVO/1000)))
  elif [ "$CONVO" -lt 10000000 ]; then NUM=$(printf '%d.%dM tok'  $((CONVO/1000000)) $(((CONVO/100000)%10)))
  else                                 NUM=$(printf '%dM tok'     $((CONVO/1000000)))
  fi

  if   [ "$CONVO" -lt 10000 ];     then SPARK="▁"; SCOLOR=$'\033[2;36m'
  elif [ "$CONVO" -lt 100000 ];    then SPARK="▂"; SCOLOR=$'\033[36m'
  elif [ "$CONVO" -lt 1000000 ];   then SPARK="▃"; SCOLOR=$'\033[36m'
  elif [ "$CONVO" -lt 10000000 ];  then SPARK="▅"; SCOLOR=$'\033[33m'
  elif [ "$CONVO" -lt 100000000 ]; then SPARK="▆"; SCOLOR=$'\033[33m'
  else                                  SPARK="█"; SCOLOR=$'\033[35m'
  fi

  TURNS=0
  if [ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ]; then
    TURNS=$(jq -s 'map(select(.message.usage)) | length' "$TRANSCRIPT" 2>/dev/null || echo 0)
  fi

  printf '  %s┃%s  %s%s %s%s %s·%s %d turns' \
    "$DIM" "$RESET" "$SCOLOR" "$SPARK" "$NUM" "$RESET" "$DIM" "$RESET" "$TURNS"
fi

# ── Burn rate (1m) + cache hit % (transcript-only metrics) ───────────
if [ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ]; then
  NOW_EPOCH=$(date -u +%s)
  RATES=$(jq -s --argjson now "$NOW_EPOCH" '
    def ts(t): t | sub("\\.[0-9]+Z"; "Z") | fromdateiso8601;
    [ .[] | select(.message.role == "assistant" and .message.usage and .timestamp) ]
    | { burn1m:
          ( [ .[] | select(ts(.timestamp) > ($now - 60))
                  | .message.usage
                  | (.input_tokens // 0) + (.output_tokens // 0)
                    + (.cache_read_input_tokens // 0)
                    + (.cache_creation_input_tokens // 0) ]
            | add // 0 ),
        cache_read:   ( [ .[] | .message.usage.cache_read_input_tokens     // 0 ] | add // 0 ),
        cache_create: ( [ .[] | .message.usage.cache_creation_input_tokens // 0 ] | add // 0 ),
        fresh_in:     ( [ .[] | .message.usage.input_tokens                // 0 ] | add // 0 ) }
    | . + { cache_pct:
              ( if (.cache_read + .cache_create + .fresh_in) > 0
                then (.cache_read * 100 / (.cache_read + .cache_create + .fresh_in)) | floor
                else -1 end ) }
  ' "$TRANSCRIPT" 2>/dev/null)

  BURN1M=$(printf '%s' "$RATES" | jq -r '.burn1m   // 0')
  CACHE=$( printf '%s' "$RATES" | jq -r '.cache_pct // -1')

  if [ "${BURN1M:-0}" -gt 0 ]; then
    if   [ "$BURN1M" -lt 1000 ];    then BURN_NUM=$(printf '%d/m'    "$BURN1M")
    elif [ "$BURN1M" -lt 1000000 ]; then BURN_NUM=$(printf '%dK/m'   $((BURN1M/1000)))
    else                                 BURN_NUM=$(printf '%d.%dM/m' $((BURN1M/1000000)) $(((BURN1M/100000)%10)))
    fi

    if   [ "$BURN1M" -lt 1000 ];   then BURN_COLOR=$'\033[2;32m'
    elif [ "$BURN1M" -lt 10000 ];  then BURN_COLOR=$'\033[36m'
    elif [ "$BURN1M" -lt 100000 ]; then BURN_COLOR=$'\033[33m'
    else                                BURN_COLOR=$'\033[31m'
    fi

    printf '  %s┃%s  %s↯ %s%s' "$DIM" "$RESET" "$BURN_COLOR" "$BURN_NUM" "$RESET"
  fi

  if [ "$CACHE" -ge 0 ]; then
    if   [ "$CACHE" -ge 90 ]; then CACHE_COLOR=$'\033[32m'
    elif [ "$CACHE" -ge 70 ]; then CACHE_COLOR=$'\033[33m'
    else                            CACHE_COLOR=$'\033[31m'
    fi
    printf '  %s┃%s  %s▦ %d%% %scache%s' \
      "$DIM" "$RESET" "$CACHE_COLOR" "$CACHE" "$DIM" "$RESET"
  fi
fi

# ── Context window (server pre-calculated) ───────────────────────────
CTX_PCT=$(printf '%s' "$INPUT" | jq -r '.context_window.used_percentage // empty')
if [ -n "$CTX_PCT" ]; then
  CTX_PCT=${CTX_PCT%.*}; [ -z "$CTX_PCT" ] && CTX_PCT=0
  [ "$CTX_PCT" -gt 100 ] && CTX_PCT=100

  CTX_LEN=10
  CTX_FILL=$((CTX_PCT * CTX_LEN / 100))
  [ "$CTX_FILL" -gt "$CTX_LEN" ] && CTX_FILL=$CTX_LEN
  CTX_EMPTY=$((CTX_LEN - CTX_FILL))

  CTX_BAR=""
  i=0; while [ "$i" -lt "$CTX_FILL"  ]; do CTX_BAR="${CTX_BAR}▰"; i=$((i+1)); done
  i=0; while [ "$i" -lt "$CTX_EMPTY" ]; do CTX_BAR="${CTX_BAR}▱"; i=$((i+1)); done

  if   [ "$CTX_PCT" -lt 50 ]; then CTX_COLOR=$'\033[36m'
  elif [ "$CTX_PCT" -lt 80 ]; then CTX_COLOR=$'\033[33m'
  else                              CTX_COLOR=$'\033[31m'
  fi

  printf '  %s┃%s  %s%s%s %d%% %sctx%s' \
    "$DIM" "$RESET" "$CTX_COLOR" "$CTX_BAR" "$RESET" "$CTX_PCT" "$DIM" "$RESET"
fi

# ── Git branch ───────────────────────────────────────────────────────
if [ -n "$CWD" ] && [ -d "$CWD" ]; then
  BRANCH=$(git -C "$CWD" symbolic-ref --quiet --short HEAD 2>/dev/null \
            || git -C "$CWD" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$BRANCH" ]; then
    printf '  %s┃%s  \033[35m⎇ %s\033[0m' "$DIM" "$RESET" "$BRANCH"
  fi
fi
