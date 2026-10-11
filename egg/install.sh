#!/bin/bash
# Project Reclaimer installer for Pelican. Runs in the installer container
# with the server volume at /mnt/server (override with INSTALL_DIR to test).
set -euo pipefail

DIR="${INSTALL_DIR:-/mnt/server}"
REPO="https://github.com/ProjectReclaimer/project-reclaimer-releases/releases"
TAG="${RELEASE_TAG:-latest}"

if ! command -v curl >/dev/null || ! command -v sha256sum >/dev/null; then
    apt-get update -qq && apt-get install -y -qq curl ca-certificates coreutils >/dev/null
fi

mkdir -p "${DIR}"
cd "${DIR}"
mkdir -p game content/Maps "content/Game Modes" content/Mods playlists data

# The checksum list names every asset, so it tells us the dedicated build's
# file name (and its version) without the rate-limited GitHub API.
if [ "${TAG}" = "latest" ]; then
    SUMS_URL="${REPO}/latest/download/SHA256SUMS.txt"
else
    SUMS_URL="${REPO}/download/${TAG}/SHA256SUMS.txt"
fi
echo "Reading release checksums: ${SUMS_URL}"
SUMS=$(curl -fsSL "${SUMS_URL}") || { echo "Could not download ${SUMS_URL}. Check the Release Tag variable."; exit 1; }

LINE=$(echo "${SUMS}" | grep -E '[[:space:]]\*?project-reclaimer-dedicated-v?[0-9][^[:space:]]*\.exe$' | head -n1 || true)
if [ -z "${LINE}" ]; then
    echo "This release has no project-reclaimer-dedicated-*.exe (it first shipped in 0.8.14). Assets listed:"
    echo "${SUMS}"
    exit 1
fi
EXPECTED=$(echo "${LINE}" | awk '{print $1}')
EXE_NAME=$(echo "${LINE}" | awk '{print $2}' | tr -d '*')
VERSION=$(echo "${EXE_NAME}" | sed -E 's/^project-reclaimer-dedicated-(.*)\.exe$/\1/')

echo "Downloading ${EXE_NAME}"
curl -fsSL -o project-reclaimer.exe.part "${REPO}/download/${VERSION}/${EXE_NAME}"

ACTUAL=$(sha256sum project-reclaimer.exe.part | awk '{print $1}')
if [ "${ACTUAL}" != "${EXPECTED}" ]; then
    echo "Checksum mismatch for ${EXE_NAME}: expected ${EXPECTED}, got ${ACTUAL}"
    rm -f project-reclaimer.exe.part
    exit 1
fi
mv -f project-reclaimer.exe.part project-reclaimer.exe
echo "${VERSION}" > .reclaimer-version
echo "Installed Project Reclaimer ${VERSION} (sha256 verified)"

# A starting config, only if there isn't one. The panel rewrites the
# [[server]] name and port lines at every start (see the egg's config).
if [ ! -f dedicated.toml ]; then
    echo "Writing dedicated.toml"
    cat > dedicated.toml <<'EOF'
# Project Reclaimer: one server per Pelican server.
#
# Managed by the panel, do not edit here:
#   - the [[server]] "name = " and "port = " lines (Startup tab / allocation)
#   - host name, admins, join password, max players (Startup tab variables,
#     which override this file through RECLAIMER_DEDICATED_* env vars)
#   - this machine's master is off; servers still list on the public masters
# Keep a single [[server]] block, and keep "name =" and "port =" unindented
# at the start of their lines, or the panel can't update them.
game = "game"
content = "content"
public_address = ""
upnp = false
auto_update = false

[rcon]
address = "127.0.0.1"

[defaults]
max_players = 16

[[server]]
name = "Reclaimer"
port = 49176
map = "Guardian"
game = "Slayer"
EOF
fi

echo "Done. Upload Halo 3's files into game/ over SFTP before the first start."
