#!/usr/bin/env bash
# Build the model-builder image with buildah, the same way on your computer and in GitHub Actions.
# Usage: model-builder/build.sh [BUILDAH BUILD OPTIONS...]
# It tags the image $IMAGE:latest, IMAGE defaulting to localhost/model-builder, and records the
# tools repo's commit and the build time in its labels. Options go to buildah build, for example
# --build-arg BLENDER_VERSION=ubuntu, or --pull=always to start from the newest Ubuntu 26.04 image.
# If docker holds a copy of the image, which run.sh makes for docker, the copy is updated too.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
image="${IMAGE:-localhost/model-builder}:latest"

labels=(--label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)")
if revision="$(git -C "$here" rev-parse HEAD 2> /dev/null)"; then
  labels+=(--label "org.opencontainers.image.revision=$revision")
fi
buildah build --layers --file "$here/Containerfile" --tag "$image" "${labels[@]}" "$@" "$here"

if command -v docker > /dev/null && docker image inspect "$image" > /dev/null 2>&1; then
  buildah push "$image" "docker-daemon:$image"
fi
echo "BUILT $image"
