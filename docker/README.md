### Usage

Run ./build.sh for help and required options. Below shows required and optional options to define build behavior, specific packages and manifest information.

### Build options in buildkite

Options can be defined within environment variables or within the environment section of the buildkite pipeline.

**Required**

* BUILD_NAME - Used and passed within the lunch command, whereby BUILD_NAME is used within the context of the lunch command; e.g. `lunch BUILD_NAME_crownlte-userdebug`
* UPLOAD_NAME - Defines the name for the folder mega uploads to; e.g `ROMS/UPLOAD_NAME/29-04-20/`

**Optional**

**Other**

Specific environment variables can be set prior to executing build.sh for defining specific build options
