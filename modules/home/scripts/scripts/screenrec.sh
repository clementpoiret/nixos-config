#!/usr/bin/env bash
set -euo pipefail

# Hyprland + Wayland screen recorder helper using wl-screenrec, zenity, slurp
# - Interactive mode (zenity): choose output and full-screen vs area
# - CLI mode: pass --screen=DP-1 and/or --selection or --geometry to skip prompts
# Always shows a "Stop" window to end the recording.
#
# Dependencies: hyprctl, wl-screenrec, zenity, slurp
# Optional: jq
#
# Examples:
#   ./wl-recorder.sh                          # interactive
#   ./wl-recorder.sh --screen=DP-1            # full screen on DP-1
#   ./wl-recorder.sh -o eDP-1 --selection     # area on eDP-1
#   ./wl-recorder.sh -g "100,100 1280x720"    # exact geometry
#   ./wl-recorder.sh --audio                  # add audio (default device)

die() {
  local msg=${1:-"Unknown error"}
  if command -v zenity >/dev/null 2>&1; then
    zenity --error --no-wrap --title="Recording error" --text="$msg" || true
  else
    printf 'Error: %s\n' "$msg" >&2
  fi
  exit 1
}

user_cancel() {
  # Clean, successful exit when user cancels a prompt
  exit 0
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"
}

need "hyprctl"
need "wl-screenrec"
need "zenity"
need "slurp"

VIDEOS_DIR="$HOME/Videos"
mkdir -p "$VIDEOS_DIR"
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"

OUTFILE="$VIDEOS_DIR/recording_${TIMESTAMP}.mp4"
LOGFILE="$(mktemp -t wl-screenrec-XXXX.log)"
cleanup() { rm -f "$LOGFILE" >/dev/null 2>&1 || true; }
trap cleanup EXIT

get_outputs() {
  if command -v jq >/dev/null 2>&1; then
    hyprctl -j monitors | jq -r '.[].name'
  else
    hyprctl -j monitors | grep -oE '"name":\s*"[^"]+"' | sed -E 's/.*"name":\s*"([^"]+)".*/\1/'
  fi
}

outputs=()
while IFS= read -r line; do
  [[ -n "$line" ]] && outputs+=("$line")
done < <(get_outputs)

(( ${#outputs[@]} >= 1 )) || die "No outputs detected."

# Defaults
SCREEN=""
MODE=""       # "full", "select", or "geometry"
GEOM=""
AUDIO=0
AUDIO_DEVICE=""
FILENAME=""

print_help() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --screen <OUTPUT> | -o <OUTPUT>   Select output (e.g., DP-1). If only this is set, records full screen.
  --selection | -s                  Use slurp to select a region (constrained to --screen if provided).
  --geometry "<x,y WxH>" | -g ...   Use explicit geometry instead of --selection.
  --audio                           Record audio from default device.
  --audio-device <NAME>             Record audio from the specified device (see: pactl list short sources).
  --filename <PATH> | -f <PATH>     Override output filename (default: ~/Videos/recording_YYYYmmdd_HHMMSS.mp4)
  --help | -h                       Show this message.

Examples:
  $(basename "$0")
  $(basename "$0") --screen=DP-1
  $(basename "$0") -o eDP-1 --selection
  $(basename "$0") -g "100,100 1280x720"
  $(basename "$0") --audio
EOF
}

# Parse CLI
while [[ $# -gt 0 ]]; do
  case "$1" in
    --screen=*|--output=*)
      SCREEN="${1#*=}"; shift ;;
    --screen|--output|-o)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      SCREEN="$2"; shift 2 ;;
    --selection|-s|--area)
      MODE="select"; shift ;;
    --geometry|-g)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      GEOM="$2"; MODE="geometry"; shift 2 ;;
    --audio)
      AUDIO=1; shift ;;
    --audio-device)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      AUDIO_DEVICE="$2"; AUDIO=1; shift 2 ;;
    --filename|-f)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      FILENAME="$2"; shift 2 ;;
    --help|-h)
      print_help; exit 0 ;;
    *)
      die "Unknown option: $1 (use --help)"
      ;;
  esac
done

# Validate screen if specified
if [[ -n "$SCREEN" ]]; then
  if ! printf '%s\n' "${outputs[@]}" | grep -qx -- "$SCREEN"; then
    die "Output '$SCREEN' not found. Available: $(printf '%s ' "${outputs[@]}")"
  fi
fi

# If filename provided, override
if [[ -n "$FILENAME" ]]; then
  OUTFILE="$FILENAME"
fi

# Decide interactive vs CLI mode:
# - If GEOM is set => geometry mode
# - Else if MODE is "select" => selection mode
# - Else if SCREEN set => full screen
# - Else interactive prompts
if [[ -n "$GEOM" ]]; then
  MODE="geometry"
elif [[ "$MODE" == "select" ]]; then
  : # already set
elif [[ -n "$SCREEN" ]]; then
  MODE="full"
else
  # Interactive (zenity)
  # 1) Output selection if multiple
  if (( ${#outputs[@]} == 1 )); then
    SCREEN="${outputs[0]}"
  else
    sel="$(printf '%s\n' "${outputs[@]}" | \
      zenity --list --title="Select screen to record" --column="Output" --height=320)"
    [[ $? -eq 0 ]] || user_cancel
    SCREEN="$sel"
    [[ -n "$SCREEN" ]] || user_cancel
  fi

  # 2) Capture mode
  msel="$(zenity --list --radiolist \
    --title="Capture mode" --height=220 \
    --column="Pick" --column="Mode" --column="Description" \
    TRUE "Full screen" "Record the entire selected output" \
    FALSE "Select area" "Use slurp to select a region on that output")"
  [[ $? -eq 0 ]] || user_cancel
  [[ -n "$msel" ]] || user_cancel
  if [[ "$msel" == "Full screen" ]]; then
    MODE="full"
  else
    MODE="select"
  fi
fi

# Build wl-screenrec args
declare -a ARGS
ARGS+=( -f "$OUTFILE" )

# Add audio if requested
if (( AUDIO == 1 )); then
  ARGS+=( --audio )
  if [[ -n "$AUDIO_DEVICE" ]]; then
    ARGS+=( --audio-device "$AUDIO_DEVICE" )
  fi
fi

# Geometry vs selection vs full
case "$MODE" in
  geometry)
    # User-provided geometry; do not add -o
    ARGS+=( -g "$GEOM" )
    ;;
  select)
    # Use slurp; constrain to SCREEN if available and if slurp supports -o
    if [[ -n "${SCREEN:-}" ]] && slurp -h 2>&1 | grep -q -- ' -o'; then
      sel_geom="$(slurp -o "$SCREEN" 2>/dev/null || true)"
    else
      sel_geom="$(slurp 2>/dev/null || true)"
    fi
    [[ -n "$sel_geom" ]] || user_cancel
    ARGS+=( -g "$sel_geom" )
    ;;
  full)
    # Full screen requires output
    if [[ -z "$SCREEN" ]]; then
      die "Internal error: full-screen mode without SCREEN"
    fi
    ARGS+=( -o "$SCREEN" )
    ;;
  *)
    die "Internal error: unknown mode '$MODE'"
    ;;
esac

# Start recording
wl-screenrec "${ARGS[@]}" >"$LOGFILE" 2>&1 &
REC_PID=$!

# Ensure we kill the recorder if the script receives INT/TERM
trap 'kill -INT $REC_PID 2>/dev/null || true; wait $REC_PID 2>/dev/null || true; exit 130' INT TERM

# Verify it started
sleep 0.3
if ! kill -0 "$REC_PID" >/dev/null 2>&1; then
  err="Failed to start recording."
  if [[ -s "$LOGFILE" ]]; then
    err+="\n\nDetails:\n$(tail -n 50 "$LOGFILE")"
  fi
  die "$err"
fi

# Show Stop window (always)
zenity --info --no-wrap --title="Recording..." \
  --text="Recording to:\n$OUTFILE\n\nClick Stop when you are done." \
  --ok-label="Stop" || true

# Stop recording cleanly
if kill -0 "$REC_PID" >/dev/null 2>&1; then
  kill -INT "$REC_PID" 2>/dev/null || true
  wait "$REC_PID" 2>/dev/null || true
fi

# Final status
if [[ -s "$OUTFILE" ]]; then
  zenity --info --no-wrap --title="Recording saved" --text="Saved:\n$OUTFILE" || true
else
  msg="Recording stopped, but output file is missing or empty:\n$OUTFILE"
  if [[ -s "$LOGFILE" ]]; then
    msg+="\n\nDetails:\n$(tail -n 50 "$LOGFILE")"
  fi
  die "$msg"
fi
