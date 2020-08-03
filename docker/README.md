### Usage

Below shows required and optional options to define build behavior, specific packages and manifest information.

### Build options in buildkite

Options can be defined within environment variables or within the environment section of the buildkite pipeline.

**Required**

* BUILD_NAME - Used and passed within the lunch command, e.g `bootleggers`, whereby BUILD_NAME is used within the context of the lunch command; e.g. `lunch BUILD_NAME_crownlte-userdebug`
* UPLOAD_NAME - Defines the folder name that mega uploads to; e.g `bootleggers` whereby UPLOAD_NAME is used within the output directory, e.g. `ROMS/UPLOAD_NAME/29-04-20/`
* DEVICES - Defines a list of devices that the build script will iterate over, seperated by a comma; e.g. `crownlte,starlte,star2lte`
* REPO - Defines the github manfifest URL for the selected rom; e.g. `https://github.com/BootleggersROM/manifest.git`
* BRANCH Defines the github branch for the specified REPO; e.g. `queso`
* LOCAL_REPO - Defines the URL of the local manifest; e.g. `https://github.com/robbalmbra/local_manifests.git`
* LOCAL_BRANCH - Defines the branch for the specified LOCAL_REPO; e.g. `android-10.0`

**Optional**

**Git options**
* GIT_EMAIL - Specify email to use for git commands
* GIT_UNAME - Specify username to use for git commands

**Instance options**
* AUTO_TERMINATE=0 - Ignores normal operation of halting instances once builds have successfully finished within aws and gcloud. Default is terminated on cloud platforms whereby build has successfully completed.
* CUSTOM_TERMINATION_COMMAND - Defines a custom termination command once building has successfully built. e.g. `halt`

**Mega file upload**
* MEGA_FOLDER_ID - Folder id of the build name being built, needed for non test builds when mega upload is used
* MEGA_DECRYPT_KEY - Decryption key for selected folder specified in MEGA_FOLDER_ID, needed for non test builds when mega upload is used
* MEGA_UPLOAD_FOLDER - Upload path relative from mega account root, e.g. `android_roms/testing`, `phone_roms`. Default is the folder path `ROMS/UPLOAD_NAME/DATE/`. Dynamic variables such as {upload_name}, {date} and {device} can be defined within the path, each of these variables will be replaced with actual values within the program, e.g. `ROMS/{upload_name}/{device}`
* MEGA_USERNAME - Specifies username for mega upload CLI
* MEGA_PASSWORD - Specifies password for mega upload CLI

**SCP file upload**
* SCP_USERNAME - Specifies the username to use during file transfer to the host
* SCP_HOST - Specifies the host to connect to, e.g. `test.git.com`
* SCP_DEST - Specifies an absolute path to upload directory, e.g. `/home/robbalmbra/project/`
* SCP_PATH - Specifies the structure within the SCP_DEST directory, e.g `PE/{device}/{date}/`. Optional - {device} will resolve to the current device being uploaded, {date} will resolve to the current date.
* SCP_LINK - Public link to where the files are hosted

**Custom file uploader**

Uploads using custom handler via a script, the script is called with the parameters `$ROM $CUSTOM_UPLOAD_FOLDER`, please specify the interpreter using a shebang in the header of the file. Whereby ROM is the absolute path to the ROM file and CUSTOM_UPLOAD_FOLDER is the path of the output directory on the upload server.
* CUSTOM_UPLOAD_NAME - Defines the name of the uploader
* CUSTOM_UPLOAD_SCRIPT - Specifies absolute script location that contains upload methods, alternatively a HTTP link to the script to download
* CUSTOM_UPLOAD_FOLDER - Specifies the folder to upload to
* CUSTOM_UPLOAD_LINK - Specifies a link to where files are hosted

**Telegram build updater**
* TELEGRAM_TOKEN - Specifies token for automatic group update after build has completed.
* TELEGRAM_GROUP - Specifies telegram group name, e.g `@groupname`
* TELEGRAM_AUTHORS - Specifies the authors for the telegram automatic group update
* TELEGRAM_SUPPORT_LINK - Specifies a http or https link to support page or group, i.e. telegram
* CHANGELOG_DAYS - Specifies how far back to retrieve changelog commits from repos

**Ccache options**
* CUSTOM_CCACHE_DIR -  Specifies alternative directory for ccache to save relevant files into for the build, e.g. `/media/data/ccache`
* CCACHE_SIZE - Defines in gigabytes the size of ccache. Default is 70 gigabytes.

**Lunch options**
* LUNCH_VERSION - Defines the lunch build option; possible options include `user,userdebug and eng`. Default is userdebug.
* CUSTOM_LUNCH_COMMAND - Overrides default lunch command. Default is lunch.

**Build options**
* MKA_PARAMETERS - Defines extra parameters to add to the mka build command; e.g. `xtended`. Default parameter is bacon.
* CUSTOM_MKA_COMMAND - Sets custom make command. Notes - {device} changes to device name and {user_debug} defaults to rom debug type.
* TEST_BUILD=1 - Disable telegram, upload to mega and via scp and termination of instances in cloud platforms.
* MAX_CPUS - Defines max CPUs to use for the building process; e.g. `MAX_CPUS=6` defines to only use 6 CPUS for the build. Default uses all CPU cores for the build.
* CUSTOM_OUTPUT_DIR - Overrides default build directory to selected directory
* DEBUG=1 - Dont flush any output to /dev/null. Default ignores output.
* SKIP_BUILD=1 - Skip build process. Default will build.
* SKIP_API_DOCS=1 - Skip API document generation
* DATE_REVERT - Specifies the date that the repo will pull before the specified date; e.g `2020-03-01 00:00`
* PRODUCE_DEVICE_TREES=1 - Apply modifications and only produce device trees.
* JUST_UPLOAD=1 - Causes build script to only upload any built files to mega and/or scp
* INSTALL_CLEAN - Overrides command for cleaning between builds, default is set to `make installclean`
* FORCE_CLEAN - Deletes previous build history on host
* RETURN_CHANGELOG=n - Only returns the changelog within the previous n days. e.g `RETURN_CHANGELOG=5` equals to the previous 5 days of commits

**Build modifications**
* USER_MODS - Defines location of custom modifications bash script to alter sources after being pulled
* ADDITIONAL_PROPS - Defines a list of props that will be appended to the build props of the build; e.g `ro.config.vc_call_steps=20;camera.eis.enable=1`. Note - Each prop is seperated by a semicolon.
* EXTRA_COMMANDS - Run user commands after sync has finished, e.g. `pwd;ls -al;git clone test.git /opt/out` Default is ignored.

**OTA**
* PROCESS_OTA=1 - Generate ota json and upload to sourceforge. Default is ignored.
* JUST_PROCESS_OTA - Only run ota generation and upload script.

**Extras**
* MAGISK_IN_BUILD=0 - Specifies to not include magisk within the build. Default is enabled.
* MAGISK_VERSION - Specifies magisk version to include within the rom; e.g `20.4`
* LIBEXYNOS_CAMERA=0 - Turns off libexynoscamera intergration into rom

**Buildkite logging**
* LOGGING_RATE - Defines rate of how often logs are updated to buildkite; e.g `LOGGING_RATE=20` defines every 20 seconds to check and pull current log for the device being built. Default is 30 seconds.

**Notes**

* Specific environment variables can be set prior to executing build.sh for defining specific build options
* SCP uploader uses a private key to connect to the server, please configurate this with your scp provider.
