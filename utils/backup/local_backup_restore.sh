#!/usr/bin/env bash
# local_backup_restore.sh
#
# Restore a GenesisL1 (Cosmos-style) snapshot from a *local* .tar.lz4 file into ~/.genesis (or custom home).
# Expectation: the archive contains a top-level "data/" directory.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  local_backup_restore.sh -i /path/to/data_snapshot.tar.lz4 [options]

Required:
  -i, --input FILE         Path to local .tar.lz4 snapshot file

Options:
  -H, --home-dir DIR       Genesis home directory (default: $HOME/.genesis)
  -d, --daemon NAME        Systemd service to stop/start (default: genesisd)
  -s, --stop-start         Stop daemon before restore and start after
  -r, --remove-existing    Remove existing "data/" before restore (DANGEROUS, but common)
  -n, --dry-run            Print what would be done (no changes)
  -h, --help               Show this help

Examples:
  ./local_backup_restore.sh -i /mnt/backup/data_12654149.tar.lz4
  ./local_backup_restore.sh -i ./data_12654149.tar.lz4 -s -r
  ./local_backup_restore.sh -i ./data_12654149.tar.lz4 -H /srv/genesis/.genesis -s -d genesisd
EOF
}

INPUT=""
HOME_DIR="${HOME}/.genesis"
DAEMON="genesisd"
DO_STOP_START=0
REMOVE_EXISTING=0
DRY_RUN=0

# --- args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--input) INPUT="${2:-}"; shift 2 ;;
    -H|--home-dir) HOME_DIR="${2:-}"; shift 2 ;;
    -d|--daemon) DAEMON="${2:-}"; shift 2 ;;
    -s|--stop-start) DO_STOP_START=1; shift ;;
    -r|--remove-existing) REMOVE_EXISTING=1; shift ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

# --- checks ---
if [[ -z "$INPUT" ]]; then
  echo "ERROR: --input is required" >&2
  usage
  exit 2
fi
if [[ ! -f "$INPUT" ]]; then
  echo "ERROR: input file not found: $INPUT" >&2
  exit 2
fi

# dependencies
command -v lz4 >/dev/null 2>&1 || { echo "ERROR: lz4 not found in PATH" >&2; exit 127; }
command -v tar >/dev/null 2>&1 || { echo "ERROR: tar not found in PATH" >&2; exit 127; }

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] $*"
  else
    eval "$@"
  fi
}

echo "==> Restoring FULL data folder snapshot (local streamed)"
echo "    input    : ${INPUT}"
echo "    home-dir  : ${HOME_DIR}"
echo "    daemon    : ${DAEMON}"
echo "    stop/start: ${DO_STOP_START}"
echo "    rm data/  : ${REMOVE_EXISTING}"
echo

run "mkdir -p \"${HOME_DIR}\""

if [[ "$DO_STOP_START" -eq 1 ]]; then
  run "systemctl stop \"${DAEMON}\""
fi

if [[ "$REMOVE_EXISTING" -eq 1 ]]; then
  run "rm -rf \"${HOME_DIR}/data\""
fi

# Optional quick sanity check: does archive contain top-level data/ ?
# (Reads only headers; still streams, no full extract.)
if [[ "$DRY_RUN" -eq 0 ]]; then
  echo "==> Checking archive contains top-level 'data/' ..."
  if ! lz4 -dc "${INPUT}" | tar -tf - | head -n 50 | grep -qE '^data/'; then
    echo "WARNING: Could not confirm 'data/' at archive root from the first entries." >&2
    echo "         If your tar stores 'data/' later, this warning can be ignored." >&2
  fi
fi

echo "==> Extracting into ${HOME_DIR} ..."
run "lz4 -dc \"${INPUT}\" | tar -xvf - -C \"${HOME_DIR}\""

if [[ "$DO_STOP_START" -eq 1 ]]; then
  run "systemctl start \"${DAEMON}\""
fi

echo "==> Done."
