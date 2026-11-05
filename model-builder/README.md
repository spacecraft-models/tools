# model-builder

A container image with the tools that build and render the spacecraft models, such as [starship](https://github.com/spacecraft-models/starship) and [dragonfly](https://github.com/spacecraft-models/dragonfly). The model repos' scripts run in it as they are, on a computer without OpenSCAD or Blender installed and in GitHub Actions.

It is built on Ubuntu 26.04 and has:

| Tool | Version | For |
|---|---|---|
| OpenSCAD | 2021.01, Ubuntu's package | `render_openscad.sh` and `export_print.sh`: PNG previews, STLs and print exports. 2021.01 is the version the models are written for. |
| Xvfb and Mesa | Ubuntu's | A virtual display, drawn in software, for OpenSCAD's PNGs. When there is no display, `openscad` starts one for each run. |
| Blender | 5.2.3, Blender's own build | `render_blender.sh`: the realistic renders and their `.blend` and `.glb` files |
| Python | 3.14, with Pillow, numpy, SciPy, trimesh, Shapely, NetworkX and Rtree | `make_sheet.py`, `print_check.py` and dragonfly's `measure_nasa_stl.py` |
| Fonts | DejaVu and Liberation | The summary sheets' lettering, and `text()` in the models |
| git and Git LFS | Ubuntu's | Checking out a repo in a GitHub Actions job |

FreeCAD isn't in it: Ubuntu 26.04 has no FreeCAD package, and neither model has a FreeCAD document, so starship's `render_freecad.sh` doesn't run in it.

| Path | What it holds |
|---|---|
| `Containerfile` | The image's recipe |
| `build.sh` | Builds the image with buildah |
| `run.sh` | Runs a command in the image, in a model repo |
| `bin/openscad` | Runs OpenSCAD on a virtual display when there is no display |
| `bin/model-builder-selftest` | Checks the image can do what the scripts need |
| `examples/render-models.yml` | A workflow for a model repo that renders its models in the image |

## Building it

Install buildah (`sudo apt install buildah` on Ubuntu), then, from the tools repo:

```bash
model-builder/build.sh
```

That builds `localhost/model-builder:latest`. The first build downloads about 600 MB and takes several minutes; later ones reuse the steps that haven't changed. Options after `build.sh` go to `buildah build`:

- `--build-arg BLENDER_VERSION=5.2.2` installs another Blender release, 4.0 or later, from blender.org, and `--build-arg BLENDER_MIRROR=https://mirrors.ocf.berkeley.edu/blender/release` downloads it from one of [its mirrors](https://www.blender.org/download/mirrors/) instead.
- `--pull=always` starts from the newest Ubuntu 26.04 image, with its latest updates.

The image installs Blender's own build rather than Ubuntu's `blender` package, because Ubuntu's (5.0.1) is built without OpenImageDenoise, which `render_blender.py` uses.

`model-builder-selftest` checks a build, printing a line for each tool it tries:

```bash
podman run --rm localhost/model-builder model-builder-selftest
```

## Running a model's scripts in it

`run.sh` runs a command in the image with the current directory, a model repo, as its working directory, so the scripts read the repo's files and write `renders/` in it as usual:

```bash
cd ~/src/starship
EDGES=0 ../spacecraft-models/tools/model-builder/run.sh scripts/render_openscad.sh model/starship.scad
../spacecraft-models/tools/model-builder/run.sh scripts/render_blender.sh model/starship.scad
../spacecraft-models/tools/model-builder/run.sh scripts/export_print.sh "1:460 print"
```

- It uses podman if it's installed, and docker otherwise; `ENGINE=docker` picks docker. Either way, the files it writes belong to you. podman runs the image buildah built as it is. docker can't see buildah's images, so `run.sh` copies the image to docker the first time and again after each new build.
- It runs the image `build.sh` made, or the published one from GitHub when there isn't one. `IMAGE=` names another.
- It passes on the scripts' settings `EDGES`, `VIEWS`, `SAMPLES` and `SCALE` when they're set.
- With no command, it opens a shell in the image.
- It hides any Python virtual environment in the repo, such as dragonfly's `source_data/.venv`, from the container. Such an environment is made for the computer's Python, and in the container it would start the image's Python without the packages the scripts need, so hiding it makes them use the image's `python3`, which has them.

To run the image some other way, mount the repo and work in it, for example `podman run --rm -it --userns=keep-id -v "$PWD:/work" localhost/model-builder`.

## In GitHub Actions

[`.github/workflows/model-builder.yml`](../.github/workflows/model-builder.yml) builds the image with `build.sh` on each pull request and push that changes it, and checks it with `model-builder-selftest`. On `main` it publishes it to the GitHub Container Registry as `ghcr.io/spacecraft-models/model-builder`, tagged `latest` and `sha-<commit>`. It also rebuilds every Monday, so the image picks up Ubuntu's security updates.

A model repo's workflow runs its steps in the image with `container:`. [`examples/render-models.yml`](examples/render-models.yml) renders each model in `model/`, plus the realistic renders where the repo has `render_blender.sh`, and keeps them as a workflow artifact. Copy it into a model repo's `.github/workflows/`.

The first publish creates the package as private. For the model repos' workflows to pull it, make it public in the package's settings on GitHub, or give each model repo read access there, under Manage Actions access, and turn on the `credentials:` lines in the workflow.
