### Usage

Run ./build.sh for help and required options. Below shows required and optional options to define build behavior, specific packages and manifest information.

### Build options in buildkite

Options can be defined within environment variables or within the environment section of the buildkite pipeline.

**Required**

* BUILD_NAME - Used and passed within the lunch command, whereby BUILD_NAME is used within the context of the lunch command; e.g. `lunch BUILD_NAME_crownlte-userdebug`
* UPLOAD_NAME - Defines the folder name that mega uploads to; e.g `ROMS/UPLOAD_NAME/29-04-20/`
* MEGA_USERNAME - Specifies username for mega upload CLI
* MEGA_PASSWORD - Specifies password for mega upload CLI
* DEVICES - Defines a list of devices that the build script will iterate over, seperated by a comma; e.g. `crownlte,starlte,star2lte`
* REPO - Defines the github manfifest URL; e.g. `https://github.com/BootleggersROM/manifest.git`
* BRANCH Defines the github branch for the specified REPO; e.g. `queso`

**Optional**

**Other**

Specific environment variables can be set prior to executing build.sh for defining specific build options
