#!/usr/bin/env bash
# Claude Code status line. Reads session JSON on stdin and prints a single
# colored line: context-usage bar, rate-limit warnings, and cost/model.
# See https://code.claude.com/docs/en/statusline for the input schema.
set -euo pipefail

input=$(cat)

# --- ANSI helpers ---------------------------------------------------------
RESET=$'\033[0m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
CYAN=$'\033[36m'
DIM=$'\033[2m'

# Pick a color for a 0-100 percentage: green <50, yellow 50-80, red >80.
pct_color() {
  local p="$1"
  if [ "$p" -gt 80 ]; then
    printf '%s' "$RED"
  elif [ "$p" -ge 50 ]; then
    printf '%s' "$YELLOW"
  else
    printf '%s' "$GREEN"
  fi
}

# --- Context usage bar ----------------------------------------------------
ctx_pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
ctx_pct=${ctx_pct:-0}
exceeds=$(printf '%s' "$input" | jq -r '.exceeds_200k_tokens // false')

bar_width=10
filled=$(( ctx_pct * bar_width / 100 ))
[ "$filled" -gt "$bar_width" ] && filled=$bar_width
[ "$filled" -lt 0 ] && filled=0
empty=$(( bar_width - filled ))

bar=""
for _ in $(seq 1 "$filled" 2>/dev/null); do bar="${bar}█"; done
for _ in $(seq 1 "$empty" 2>/dev/null); do bar="${bar}░"; done

cc=$(pct_color "$ctx_pct")
segment="${cc}[${bar}] ${ctx_pct}% ctx${RESET}"
if [ "$exceeds" = "true" ]; then
  segment="${segment} ${RED}⚠200k+${RESET}"
fi
out="$segment"

# --- Rate-limit warnings (subscription only; silent when absent) ----------
fmt_reset() {
  # $1 = unix epoch seconds; print a short "resets in Xh Ym" hint if in future.
  local at="$1" now diff h m
  [ -z "$at" ] && return 0
  now=$(date +%s)
  diff=$(( at - now ))
  [ "$diff" -le 0 ] && return 0
  h=$(( diff / 3600 ))
  m=$(( (diff % 3600) / 60 ))
  if [ "$h" -gt 0 ]; then
    printf ' resets %dh%dm' "$h" "$m"
  else
    printf ' resets %dm' "$m"
  fi
}

rl_segment() {
  # $1 = label, $2 = used_percentage (or empty), $3 = resets_at (or empty)
  local label="$1" pct="$2" at="$3"
  [ -z "$pct" ] && return 0
  pct=$(printf '%s' "$pct" | cut -d. -f1)
  # Only surface when meaningfully consumed; escalate color as it climbs.
  [ "$pct" -lt 50 ] && return 0
  local c
  c=$(pct_color "$pct")
  printf ' %s%s %s%%%s%s' "$c" "$label" "$pct" "$(fmt_reset "$at")" "$RESET"
}

five_pct=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_at=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_pct=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_at=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

out="${out}$(rl_segment "5h" "$five_pct" "$five_at")"
out="${out}$(rl_segment "7d" "$week_pct" "$week_at")"

# --- Cost & model ---------------------------------------------------------
model=$(printf '%s' "$input" | jq -r '.model.display_name // empty')
effort=$(printf '%s' "$input" | jq -r '.effort.level // empty')
cost=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // empty')

meta="${DIM}"
[ -n "$model" ] && meta="${meta} ${CYAN}${model}${RESET}${DIM}"
[ -n "$effort" ] && meta="${meta}/${effort}"
if [ -n "$cost" ]; then
  meta="${meta} \$$(printf '%.4f' "$cost")"
fi
meta="${meta}${RESET}"

out="${out}  ${meta}"

printf '%b\n' "$out"
