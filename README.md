Tools for building/rendering models

| Path | What it holds |
|---|---|
| [`model-builder/`](model-builder/README.md) | A container image with OpenSCAD, Blender and Python, which runs the model repos' build and render scripts on your computer and in GitHub Actions, and the scripts that build it with buildah and run it |
| `.github/workflows/model-builder.yml` | Builds the image, checks it and publishes it to the GitHub Container Registry |
