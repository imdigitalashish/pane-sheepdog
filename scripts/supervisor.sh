#!/bin/bash
# Herdr supervisor: watches worker panes and wakes the orchestrator pane when
# work lands, so progress does not stall while the orchestrator is between turns.
#
# Usage: supervisor.sh <orchestrator-pane> <worker-pane>...
#   HERDR_WORK_DIR  shared directory for worker output (default /tmp/herdr_work)
#   HERDR_POLL_SECS seconds between status polls (default 15)
#
# Run it in its own pane so it outlives any single orchestrator turn:
#   herdr pane split <pane> --direction down --ratio 0.2 --no-focus
#   herdr pane run <new-pane> "<this-script> wB:p1 wB:p2 wB:p3"

set -uo pipefail

ORCH_PANE="${1:?orchestrator pane id required}"
shift
WORKERS=("$@")

if (( ${#WORKERS[@]} == 0 )); then
  echo "usage: supervisor.sh <orchestrator-pane> <worker-pane>..." >&2
  exit 2
fi

WORK_DIR="${HERDR_WORK_DIR:-/tmp/herdr_work}"
POLL_SECS="${HERDR_POLL_SECS:-15}"
INBOX_DIR="$WORK_DIR/inbox"
STATE_DIR="$WORK_DIR/.supervisor"
LOG="$STATE_DIR/supervisor.log"

mkdir -p "$STATE_DIR" "$INBOX_DIR"

log() {
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$LOG"
}

# The orchestrator pane is shared with a human. Waking it means typing into that
# human's input line, so only do it when the pane is idle (no turn running) and
# the human has not started composing a message.
orchestrator_safe_to_wake() {
  local status tail_out
  status="$(herdr agent get "$ORCH_PANE" 2>/dev/null)" || return 1
  case "$status" in
    *'"agent_status":"idle"'*) ;;
    *) return 1 ;;
  esac

  # An untouched agent prompt still shows its placeholder text. Anything else
  # means the human has started composing and must not be interrupted.
  tail_out="$(herdr pane read "$ORCH_PANE" --lines 6 2>/dev/null)" || return 1
  case "$tail_out" in
    *'Ask Codex to do anything'*|*'Try "'*) return 0 ;;
    *) return 1 ;;
  esac
}

wake_orchestrator() {
  local msg="$1"
  local attempt=0
  while (( attempt < 60 )); do
    if orchestrator_safe_to_wake; then
      herdr agent prompt "$ORCH_PANE" "$msg" >/dev/null 2>&1 && {
        log "WOKE orchestrator: $msg"
        return 0
      }
    fi
    attempt=$((attempt + 1))
    sleep 10
  done
  log "GAVE UP waking orchestrator (human busy 10m): $msg"
  return 1
}

log "supervisor start; orchestrator=$ORCH_PANE workers=${WORKERS[*]} work_dir=$WORK_DIR"
herdr notification show "Herdr supervisor online" \
  --body "Watching ${#WORKERS[@]} workers" --sound none >/dev/null 2>&1

while true; do
  all_idle=1

  for pane in "${WORKERS[@]}"; do
    info="$(herdr agent get "$pane" 2>/dev/null)"
    if [[ -z "$info" ]]; then
      # Pane can drop out of the registry briefly during re-detection.
      log "no registry entry for $pane, will retry"
      all_idle=0
      continue
    fi

    case "$info" in
      *'"agent_status":"idle"'*) cur=idle ;;
      *'"agent_status":"blocked"'*) cur=blocked ;;
      *'"agent_status":"working"'*) cur=working ;;
      *) cur=unknown ;;
    esac

    [[ "$cur" == "working" ]] && all_idle=0

    state_file="$STATE_DIR/${pane//:/_}.state"
    prev="$(cat "$state_file" 2>/dev/null || echo none)"

    if [[ "$cur" != "$prev" ]]; then
      printf '%s' "$cur" >"$state_file"
      log "$pane $prev -> $cur"

      # A worker going idle or blocked is the event worth escalating.
      if [[ "$cur" == "blocked" ]]; then
        herdr notification show "Worker blocked" --body "$pane needs input" --sound request >/dev/null 2>&1
        wake_orchestrator "SUPERVISOR ALERT: worker $pane is BLOCKED and needs input. Inspect with: herdr agent read $pane --source recent-unwrapped --lines 120"
      elif [[ "$cur" == "idle" && "$prev" == "working" ]]; then
        herdr notification show "Worker finished" --body "$pane went idle" --sound done >/dev/null 2>&1
        wake_orchestrator "SUPERVISOR ALERT: worker $pane finished and is idle. Collect its output from $WORK_DIR and the inbox files in $INBOX_DIR, then decide the next delegation."
      fi
    fi
  done

  if (( all_idle )); then
    if [[ ! -f "$STATE_DIR/all_idle_reported" ]]; then
      : >"$STATE_DIR/all_idle_reported"
      log "all workers idle"
      wake_orchestrator "SUPERVISOR ALERT: ALL workers are idle. Every delegated task has settled. Review $WORK_DIR and dispatch the next round."
    fi
  else
    rm -f "$STATE_DIR/all_idle_reported"
  fi

  sleep "$POLL_SECS"
done
