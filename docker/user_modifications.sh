#!/bin/bash

BUILD_DIR=$1;

# Patch evox framework options

# config_deviceHardwareKeys 72
sed -i 's#<integer name="config_deviceHardwareKeys">.*#<integer name="config_deviceHardwareKeys">72</integer>#' "$BUILD_DIR/rom/frameworks/base/core/res/res/values/evolution_config.xml"

# config_deviceHardwareWakeKeys 73
sed -i 's#<integer name="config_deviceHardwareWakeKeys">.*#<integer name="config_deviceHardwareWakeKeys">73</integer>#' evolution_config.xml "$BUILD_DIR/rom/frameworks/base/core/res/res/values/evolution_config.xml"

# config_haveHigherAspectRatioScreen true
sed -i 's#<bool name="config_haveHigherAspectRatioScreen">.*#<bool name="config_haveHigherAspectRatioScreen">true</bool>#' evolution_config.xml "$BUILD_DIR/rom/frameworks/base/core/res/res/values/evolution_config.xml"

# Other

cd "$BUILD_DIR/rom/device/samsung/universal9810-common/"
sed -i '/^SamsungD/d' universal9810-common.mk
sed -i '/^DEVICE/d' BoardConfigCommon.mk
sed -i '/^SamsungD/d' universal9810-common.mk

cd ../starlte/
sed -i 's/lineage/aosp/g' AndroidProducts.mk
mv lineage_starlte.mk aosp_starlte.mk
sed -i 's/lineage/aosp/g' aosp_starlte.mk

cd ../star2lte/
sed -i 's/lineage/aosp/g' AndroidProducts.mk
mv lineage_star2lte.mk aosp_star2lte.mk
sed -i 's/lineage/aosp/g' aosp_star2lte.mk

cd ../crownlte/
sed -i 's/lineage/aosp/g' AndroidProducts.mk
mv lineage_crownlte.mk aosp_crownlte.mk
sed -i 's/lineage/aosp/g' aosp_crownlte.mk

cd "$BUILD_DIR/rom/hardware/samsung/"
sed -i '46d' Android.mk
sed -i '22,24d' AdvancedDisplay/Android.mk
rm -rf hidl/power

# Override OTA sources
sed -i 's~https://raw.githubusercontent.com/Evolution-X-Devices/official_devices/master/builds/%s.json~https://raw.githubusercontent.com/robbalmbra/devices/master/builds/%s.json~g' "$BUILD_DIR/rom/packages/apps/Updates/src/org/evolution/ota/misc/Constants.java"
sed -i 's~https://raw.githubusercontent.com/Evolution-X-Devices/official_devices/master/changelogs/%s/%s.txt~https://raw.githubusercontent.com/robbalmbra/devices/master/changelogs/%s/%s.txt~g' "$BUILD_DIR/rom/packages/apps/Updates/src/org/evolution/ota/misc/Constants.java"

export CUSTOM_BUILD_TYPE=UNOFFICIAL
export TARGET_BOOT_ANIMATION_RES=1080
export TARGET_GAPPS_ARCH=arm64
export TARGET_SUPPORTS_GOOGLE_RECORDER=true
