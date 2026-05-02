#!/usr/bin/env bash
set -euo pipefail

# exe.dev VM bootstrap — fetches this repository and runs setup.sh.
# Usage: cat bootstrap.sh | ssh exe.dev new --setup-script /dev/stdin
# Or set as default: cat bootstrap.sh | ssh exe.dev defaults write dev.exe new.setup-script

REPO="khangkontum/exe-setup"
REPO_API="https://api.github.com/repos/$REPO?v=$(date +%s)"
TMPDIR=$(mktemp -d /tmp/exe-setup.XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

echo "[exe-setup] Fetching repository metadata..."
REPO_JSON=$(curl -fsSL "$REPO_API")
TARBALL_URL=$(echo "$REPO_JSON" | jq -r '.tarball_url')
DEFAULT_BRANCH=$(echo "$REPO_JSON" | jq -r '.default_branch // "main"')
if [ -z "$TARBALL_URL" ] || [ "$TARBALL_URL" = "null" ]; then
  echo "[exe-setup] tarball_url was null, constructing from default_branch ($DEFAULT_BRANCH)..."
  TARBALL_URL="https://api.github.com/repos/$REPO/tarball/$DEFAULT_BRANCH"
fi

echo "[exe-setup] Downloading latest $REPO tarball..."
curl -fL --retry 3 "$TARBALL_URL" -o "$TMPDIR/repo.tar.gz"

mkdir -p "$TMPDIR/repo"
tar xzf "$TMPDIR/repo.tar.gz" -C "$TMPDIR/repo" --strip-components=1

if [ ! -f "$TMPDIR/repo/setup.sh" ]; then
  echo "[exe-setup] ERROR: repository tarball did not contain setup.sh" >&2
  exit 1
fi

chmod +x "$TMPDIR/repo/setup.sh"
echo "[exe-setup] Running setup script..."
bash "$TMPDIR/repo/setup.sh"
