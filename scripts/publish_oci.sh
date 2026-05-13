#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?usage: publish_oci.sh <version>}"
IMAGE="${IMAGE:-ghcr.io/jdmacd/steampipe-plugin-gitlab}"
DIST="$(git rev-parse --show-toplevel)/dist"
GITHUB_TOKEN="$(gh auth token)"
GH_USER="$(gh api user --jq .login)"

echo "$GITHUB_TOKEN" | oras login ghcr.io -u "$GH_USER" --password-stdin

# Config blob Steampipe expects
CONFIG_FILE=$(mktemp --suffix=.json)
cat > "$CONFIG_FILE" <<EOF
{"schemaVersion":"2020-11-18","plugin":{"name":"gitlab","organization":"${GH_USER}","version":"${VERSION}"}}
EOF

# Build the layer args — include only platforms with archives present
declare -A media_types=(
  [darwin_amd64]="application/vnd.turbot.steampipe.plugin.darwin-amd64.layer.v1+gzip"
  [darwin_arm64]="application/vnd.turbot.steampipe.plugin.darwin-arm64.layer.v1+gzip"
  [linux_amd64]="application/vnd.turbot.steampipe.plugin.linux-amd64.layer.v1+gzip"
  [linux_arm64]="application/vnd.turbot.steampipe.plugin.linux-arm64.layer.v1+gzip"
)

layer_args=()
pushd "$DIST" > /dev/null
for p in darwin_amd64 darwin_arm64 linux_amd64 linux_arm64; do
  archive="steampipe-plugin-gitlab_${p}.gz"
  if [[ -f "$archive" ]]; then
    layer_args+=("${archive}:${media_types[$p]}")
    echo "  + $p"
  else
    echo "  - $p (skipped, no archive)"
  fi
done
popd > /dev/null

echo "Pushing ${IMAGE}:${VERSION}..."
pushd "$DIST" > /dev/null
oras push "${IMAGE}:${VERSION}" \
  --config "${CONFIG_FILE}:application/vnd.turbot.steampipe.config.v1+json" \
  "${layer_args[@]}"
popd > /dev/null

rm -f "$CONFIG_FILE"

oras tag "${IMAGE}:${VERSION}" "${IMAGE}:latest"

echo "Done. Install with:"
echo "  steampipe plugin install ${IMAGE}:${VERSION}"
