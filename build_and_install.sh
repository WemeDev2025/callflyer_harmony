#!/bin/bash
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
export PATH="/Users/zhaojing/Library/OpenHarmony/Sdk/18/toolchains:$PATH"
cd /Users/zhaojing/Downloads/callflyer_Harmony/Downloads/callflyer_Harmony
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleApp
/Users/zhaojing/Library/OpenHarmony/Sdk/18/toolchains/hdc install -r /Users/zhaojing/Downloads/callflyer_Harmony/Downloads/callflyer_Harmony/entry/build/default/outputs/default/entry-default-signed.hap
/Users/zhaojing/Library/OpenHarmony/Sdk/18/toolchains/hdc shell "aa start -a EntryAbility -b com.callflyer.app"
