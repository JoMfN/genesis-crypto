#!/usr/bin/env bash
set -euo pipefail

trap 'echo "ERROR: Script failed at line $LINENO. Check logs above."; exit 1' ERR

MONIKER="${1:-}"
FLAG="${2:-}"

if [[ -z "${MONIKER}" ]]; then
  echo "Usage: $0 <moniker> [--i-am-sure]"
  exit 1
fi

# -------- Chain / binary settings --------
CHAIN_ID="genesis_29-2"
HOME_DIR="${HOME}/.genesis"

REPO_DIR="${HOME}/genesis-crypto"
REPO_URL="https://github.com/GenesisL1/genesis-crypto.git"
VERSION_TAG="v1.0.0"

GENESIS_URL="https://raw.githubusercontent.com/GenesisL1/genesis-parameters/main/genesis_29-2/genesis.json"

# Full data folder snapshot (contains ./data/* at archive root) - see http://lcserve.zip for more updated download url
SNAPSHOT_URL="https://ftp.basementnodes.ca/snapshots/gl1/data.tar.lz4"

# Networking
SEEDS=""
PERSISTENT_PEERS="c1a4ec51bf9639672d9a43b592ec37fadab403f7@65.109.28.177:21496,ae950870ded893af511bcd98ecdbac9b8e844e91@65.21.205.132:26656,3985c968899e7344991ba3589c95b0e6a0ce982c@188.165.211.196:26656,2646a043e1f0c766c5b704463a7d811e100ec7f3@158.69.253.120:26656,0d07fb60f8491f4b53a6b58ae0ce60d4c69be506@135.181.183.88:26656,7757fdee74e8d33ecaa63ead16b3564cb9dea258@85.10.200.11:26656,ef7d81eb8db7ad59b4ce30e022c758cee8dc174f@188.165.202.131:26656,673ec772091d7c4e4dc8af7ed00edea4c8d334ac@65.21.196.125:26656,0d8f14bfcd680a471c4c181590b7a6910544115d@188.40.91.228:26656,0936e624c45ff1ac4089856da2beea148ee6c8de@62.171.183.162:26656,af405a6c392b747aa74704ad0ee8585b8ce164b3@37.187.95.163:26656,0f9ad819318bfa9735603736aa4c6265f666a7d9@5.135.143.103:26656,060585a1cc1fa88b4188a2d94de07b518dc188cf@144.91.84.196:26656,62cb81bad72ed77c776c7fec0547b09bdc5ceb22@158.69.253.103:26656,1d07c049908e614f5d00bf64539581178a2a7f0d@192.99.5.180:26656,be81a20b7134552e270774ec861c4998fabc2969@5.189.128.191:26656,70c201d6568e0ddf1ebe105df06b957cbc255a8b@46.4.108.77:26656,1c41828553d7ed77fb778be9c9c48a8070958744@174.138.180.190:61356,ac8056270101705557e14291dc0c98ef4f65c514@65.109.18.209:26656,75525c6609cf1600d62531b0f4bb2dc4a1f81020@187.85.19.63:26656,9c975c7f6b56c3f09ece4cb3cc9560af836f0ea0@85.122.195.176:26656"

# App params
MIN_GAS_PRICES="50000000000el1"
PRUNING_MODE="default"

# Consensus timing
TIMEOUT_COMMIT="14s"

# State sync toggle (harmless when full DB is present)
STATE_SYNC_ENABLE="true"

STATE_SYNC_RPC_SERVERS="https://api1.lcserve.eu,https://26657.genesisl1.org:443"

STATE_SYNC_TRUST_PERIOD="168h0m0s"

# ---------------- Helper Functions --------------------------

pick_working_rpc() {
  local rpcs_csv="$1"
  local IFS=','
  local -a RPCS
  read -ra RPCS <<< "$rpcs_csv"

  for rpc in "${RPCS[@]}"; do
    rpc="$(echo "$rpc" | xargs)" # trim
    # ensure no trailing slash
    rpc="${rpc%/}"

    if curl -fsS "${rpc}/status" >/dev/null 2>&1; then
      echo "${rpc}"
      return 0
    fi
  done
  return 1
}

compute_statesync_trust() {
  local rpc="$1"
  local latest rounded trust_height trust_hash
  rpc="${rpc%/}"

  latest="$(curl -fsS "${rpc}/status" | jq -r '.result.sync_info.latest_block_height')"
  if [[ -z "${latest}" || "${latest}" == "null" ]]; then
    return 1
  fi

  local ROUND_BASE=10000
  local BUFFER=10000
  rounded=$(( (latest / ROUND_BASE) * ROUND_BASE ))
  trust_height=$(( rounded - BUFFER ))
  if (( trust_height < 1 )); then trust_height=1; fi

  trust_hash="$(curl -fsS "${rpc}/block?height=${trust_height}" | jq -r '.result.block_id.hash')"
  if [[ -z "${trust_hash}" || "${trust_hash}" == "null" ]]; then
    return 1
  fi

  echo "${latest} ${trust_height} ${trust_hash}"
}

update_statesync_section() {
  local cfg="$1"
  local enable="$2"
  local rpc_servers="$3"
  local trust_height="$4"
  local trust_hash="$5"
  local trust_period="$6"

  awk -v enable="${enable}" \
      -v rpc_servers="${rpc_servers}" \
      -v trust_height="${trust_height}" \
      -v trust_hash="${trust_hash}" \
      -v trust_period="${trust_period}" '
    BEGIN { in_ss=0 }
    /^\[statesync\]/ { in_ss=1; print; next }
    /^\[/ && $0 !~ /^\[statesync\]/ { in_ss=0; print; next }
    in_ss==1 && $1=="enable" { print "enable = " enable; next }
    in_ss==1 && $1=="rpc_servers" { print "rpc_servers = \"" rpc_servers "\""; next }
    in_ss==1 && $1=="trust_height" { print "trust_height = " trust_height; next }
    in_ss==1 && $1=="trust_hash" { print "trust_hash = \"" trust_hash "\""; next }
    in_ss==1 && $1=="trust_period" { print "trust_period = \"" trust_period "\""; next }
    { print }
  ' "${cfg}" > "${cfg}.tmp" && mv "${cfg}.tmp" "${cfg}"
}

# ---------------- Dependency Install --------------------------
# Go
GO_VER="1.24.13"

echo "==> Installing OS dependencies"
sudo apt update
sudo apt install -y \
  curl wget tar build-essential git make gcc \
  jq ca-certificates rsync lz4 pv

echo "==> Installing Go ${GO_VER}"
ARCH="$(uname -m)"
if [[ "${ARCH}" == "x86_64" ]]; then
  GO_TAR="go${GO_VER}.linux-amd64.tar.gz"
elif [[ "${ARCH}" == "aarch64" || "${ARCH}" == "arm64" ]]; then
  GO_TAR="go${GO_VER}.linux-arm64.tar.gz"
else
  echo "Unsupported architecture: ${ARCH}"
  exit 1
fi

cd "${HOME}"
wget -q "https://go.dev/dl/${GO_TAR}"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "${GO_TAR}"
rm -f "${GO_TAR}"

if ! grep -q '/usr/local/go/bin' "${HOME}/.bash_profile" 2>/dev/null; then
  echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> "${HOME}/.bash_profile"
fi
# shellcheck disable=SC1090
source "${HOME}/.bash_profile"
go version

echo "==> Building genesisd (${VERSION_TAG})"
rm -rf "${REPO_DIR}"
git clone "${REPO_URL}" "${REPO_DIR}"
cd "${REPO_DIR}"
git checkout "${VERSION_TAG}"
make install

echo "==> Creating fresh home at ${HOME_DIR}"
rm -rf "${HOME_DIR}"
genesisd init "${MONIKER}" --chain-id "${CHAIN_ID}" --home "${HOME_DIR}"

echo "==> Fetching genesis.json"
curl -Ls "${GENESIS_URL}" > "${HOME_DIR}/config/genesis.json"

echo "==> Configuring config.toml / app.toml"
# peers
sed -i -e "s|^seeds *=.*|seeds = \"${SEEDS}\"|" \
       -e "s|^persistent_peers *=.*|persistent_peers = \"${PERSISTENT_PEERS}\"|" \
       "${HOME_DIR}/config/config.toml"

# consensus timing
sed -i -e "s|^timeout_commit *=.*|timeout_commit = \"${TIMEOUT_COMMIT}\"|" \
       "${HOME_DIR}/config/config.toml"

# state-sync enable (won't activate if local state exists; safe to keep on)
# NOTE: This replaces the first "enable =" it sees. In this config file it's under [statesync].
sed -i -e "0,/^enable *=.*$/s//enable = ${STATE_SYNC_ENABLE}/" \
       "${HOME_DIR}/config/config.toml"

# gas / pruning
sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"${MIN_GAS_PRICES}\"|" \
       -e "s|^pruning *=.*|pruning = \"${PRUNING_MODE}\"|" \
       "${HOME_DIR}/config/app.toml"

echo "==> Installing systemd service"
SERVICE_FILE="/etc/systemd/system/genesisd.service"
sudo tee "${SERVICE_FILE}" >/dev/null <<EOF
[Unit]
Description=genesisd
After=network-online.target

[Service]
User=${USER}
ExecStart=$(command -v genesisd) start --home ${HOME_DIR}
Restart=on-failure
RestartSec=15
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

echo "==> Auto-configuring state-sync trust params"
WORKING_RPC="$(pick_working_rpc "${STATE_SYNC_RPC_SERVERS}")" || {
  echo "WARNING: No working RPC found for state-sync from: ${STATE_SYNC_RPC_SERVERS}"
  echo "         Leaving rpc_servers/trust_height/trust_hash unchanged."
  WORKING_RPC=""
}

if [[ -n "${WORKING_RPC}" ]]; then
  if read -r LATEST_HEIGHT TRUST_HEIGHT TRUST_HASH < <(compute_statesync_trust "${WORKING_RPC}"); then
    echo "    RPC: ${WORKING_RPC}"
    echo "    LATEST_BLOCK_HEIGHT: ${LATEST_HEIGHT}"
    echo "    TRUST_HEIGHT: ${TRUST_HEIGHT}"
    echo "    TRUST_HASH: ${TRUST_HASH}"

    update_statesync_section \
      "${HOME_DIR}/config/config.toml" \
      "${STATE_SYNC_ENABLE}" \
      "${STATE_SYNC_RPC_SERVERS}" \
      "${TRUST_HEIGHT}" \
      "${TRUST_HASH}" \
      "${STATE_SYNC_TRUST_PERIOD}"
  else
    echo "WARNING: Failed to compute trust params from ${WORKING_RPC}"
  fi
fi


sudo systemctl daemon-reload
sudo systemctl enable genesisd

echo "==> Stopping service (if running) before snapshot restore"
sudo systemctl stop genesisd || true

# ---------------- SAFETY GUARD ----------------
# If this box has a real validator key, require explicit confirmation.
PV_KEY="${HOME_DIR}/config/priv_validator_key.json"

# "default" empty-ish key fingerprints differ across init runs; safest check is:
# - file exists
# - AND is non-trivial size
# - AND user didn't pass --i-am-sure
if [[ -f "${PV_KEY}" ]]; then
  KEY_BYTES="$(wc -c < "${PV_KEY}" | tr -d ' ')"
  if [[ "${KEY_BYTES}" -gt 200 && "${FLAG}" != "--i-am-sure" ]]; then
    echo
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "SAFETY CHECK: ${PV_KEY} exists and looks like a real validator key."
    echo "This installer will REPLACE ~/.genesis/data with a snapshot."
    echo
    echo "If this is a validator machine, you can cause downtime or (if mismanaged)"
    echo "double-sign risk if you later restore incorrectly."
    echo
    echo "To proceed, re-run with:  $0 \"${MONIKER}\" --i-am-sure"
    echo "Or type YES below to proceed interactively."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    read -r -p "Type YES to continue: " CONFIRM
    if [[ "${CONFIRM}" != "YES" ]]; then
      echo "Aborted."
      exit 1
    fi
  fi
fi
# ----------------------------------------------

echo "==> Preserving priv_validator_state.json"
mkdir -p "${HOME_DIR}/data"
PV_STATE_TMP="/tmp/priv_validator_state.json.$(date +%s)"
if [[ -f "${HOME_DIR}/data/priv_validator_state.json" ]]; then
  cp "${HOME_DIR}/data/priv_validator_state.json" "${PV_STATE_TMP}"
else
  echo '{"height":"0","round":0,"step":0}' > "${PV_STATE_TMP}"
fi

echo "==> Removing any existing data dir"
rm -rf "${HOME_DIR}/data"
mkdir -p "${HOME_DIR}"

echo "==> Determining snapshot size (for progress bar)"
# Try to fetch Content-Length. If missing, pv still shows throughput without a %.
SNAP_SIZE_BYTES="$(curl -sI "${SNAPSHOT_URL}" | awk -F': ' 'tolower($1)=="content-length"{print $2}' | tr -d '\r' || true)"
if [[ -n "${SNAP_SIZE_BYTES}" ]]; then
  echo "    -> Remote archive size: ${SNAP_SIZE_BYTES} bytes"
else
  echo "    -> Remote archive size: unknown (no Content-Length)."
fi

echo "==> Restoring FULL data folder snapshot (streamed): ${SNAPSHOT_URL}"
# Expectation: archive contains top-level "data/" directory.
# Use pv for progress. If size known, pass -s for % bar.
if [[ -n "${SNAP_SIZE_BYTES}" ]]; then
  wget -qO- "${SNAPSHOT_URL}" \
    | pv -s "${SNAP_SIZE_BYTES}" \
    | lz4 -d \
    | tar -xvf - -C "${HOME_DIR}"
else
  wget -qO- "${SNAPSHOT_URL}" \
    | pv \
    | lz4 -d \
    | tar -xvf - -C "${HOME_DIR}"
fi

echo "==> Sanity check: required folders exist"
if [[ ! -d "${HOME_DIR}/data" ]]; then
  echo "ERROR: Snapshot did not create ${HOME_DIR}/data. Archive layout may be unexpected."
  exit 1
fi

if [[ ! -d "${HOME_DIR}/data/blockstore.db" && ! -d "${HOME_DIR}/data/state.db" && ! -d "${HOME_DIR}/data/application.db" ]]; then
  echo "WARNING: data/ exists but expected DB dirs were not found (blockstore.db/state.db/application.db)."
  echo "         If genesisd fails to start, your archive might not be a full data snapshot."
fi

echo "==> Restoring priv_validator_state.json"
mkdir -p "${HOME_DIR}/data"
mv -f "${PV_STATE_TMP}" "${HOME_DIR}/data/priv_validator_state.json"

echo "==> Starting genesisd"
sudo systemctl start genesisd

echo "==> Done."
echo "Logs:   journalctl -fu genesisd -o cat"
echo "Status: genesisd status | jq"
echo "RPC:    curl -s localhost:26657/status | jq '.result.sync_info'"
