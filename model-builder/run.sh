#!/usr/bin/env bash
# Run a command in the model-builder image, in the current directory, so a model repo's scripts run
# without OpenSCAD or Blender installed. From a model repo:
#     EDGES=0 ../spacecraft-models/tools/model-builder/run.sh scripts/render_openscad.sh model/starship.scad
# With no command it opens a shell. The current directory is mounted as the container's working
# directory, so the scripts read the repo and write renders/ in it as usual.
# - It uses podman if it's installed, and otherwise docker (ENGINE=docker picks docker). Either way
#   the files it writes belong to you.
# - The image is the one build.sh made, or else the published one; IMAGE= names another.
# - It passes on the scripts' settings EDGES, VIEWS, SAMPLES and SCALE if they're set.
set -euo pipefail
local_image=localhost/model-builder:latest
published=ghcr.io/spacecraft-models/model-builder:latest

engine="${ENGINE:-}"
if [ -z "$engine" ]; then
  if command -v podman > /dev/null; then engine=podman
  elif command -v docker > /dev/null; then engine=docker
  else echo "run.sh needs podman or docker" >&2; exit 2
  fi
fi

created() { # the build time build.sh labels an image with; $1 is buildah or docker
  local format='{{index .Config.Labels "org.opencontainers.image.created"}}'
  [ "$1" = buildah ] && format='{{index .OCIv1.Config.Labels "org.opencontainers.image.created"}}'
  "$1" inspect --type image --format "$format" "$local_image" 2> /dev/null
}

image="${IMAGE:-}"
if [ -z "$image" ]; then
  image="$published"
  if [ "$engine" = docker ] && command -v buildah > /dev/null && built="$(created buildah)" && [ -n "$built" ]; then
    # docker can't see buildah's images, so it gets a copy, refreshed when build.sh makes a new one
    [ "$(created docker || true)" = "$built" ] || buildah push "$local_image" "docker-daemon:$local_image" >&2
    image="$local_image"
  elif "$engine" image inspect "$local_image" > /dev/null 2>&1; then
    image="$local_image"
  fi
fi

args=(run --rm --volume "$PWD:/work" --workdir /work)
[ -t 0 ] && [ -t 1 ] && args+=(--interactive --tty)
if [ "$(id -u)" != 0 ]; then
  case "$engine" in
    podman) args+=(--userns=keep-id) ;;
    *) args+=(--user "$(id -u):$(id -g)") ;;
  esac
fi
for name in EDGES VIEWS SAMPLES SCALE; do
  if [ -n "${!name+set}" ]; then args+=(--env "$name"); fi
done
# A Python virtual environment in the repo, such as dragonfly's source_data/.venv, would run the
# image's python3 without the image's packages, as it was made for this computer's Python. Covering
# it with an empty folder makes the scripts use the image's python3 directly. (podman would fill
# the folder with what it covers unless told not to.)
empty=""
[ "$engine" = podman ] && empty=":notmpcopyup"
while IFS= read -r venv; do
  args+=(--tmpfs "/work/${venv#./}$empty")
done < <(find . -maxdepth 3 -type d -name .venv -prune 2> /dev/null)

exec "$engine" "${args[@]}" "$image" "$@"
