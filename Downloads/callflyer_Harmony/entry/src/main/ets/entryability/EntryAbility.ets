import UIAbility from '@ohos.app.ability.UIAbility';
import hilog from '@ohos.hilog';
import window from '@ohos.window';
import Want from '@ohos.app.ability.Want';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
import { Configuration, AbilityConstant } from '@kit.AbilityKit';

const TAG = 'EntryAbility';
const DOMAIN = 0x0001;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    hilog.info(DOMAIN, TAG, 'EntryAbility onCreate');
    // 保存当前颜色模式到 AppStorage
    AppStorage.setOrCreate('colorMode', this.context.config.colorMode ?? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
  }

  onConfigurationUpdate(newConfig: Configuration) {
    hilog.info(DOMAIN, TAG, 'onConfigurationUpdate colorMode: %{public}s', JSON.stringify(newConfig.colorMode));
    // 同步最新颜色模式到 AppStorage，供页面监听
    AppStorage.setOrCreate('colorMode', newConfig.colorMode ?? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
  }

  onDestroy() {
    hilog.info(DOMAIN, TAG, 'EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    hilog.info(DOMAIN, TAG, 'EntryAbility onWindowStageCreate');

    // 请求通知授权
    notificationManager.requestEnableNotification(this.context).then(() => {
      hilog.info(DOMAIN, TAG, '[ANS] requestEnableNotification success');
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, '[ANS] requestEnableNotification failed, code is %{public}d, message is %{public}s', err.code, err.message);
    });

    windowStage.loadContent('pages/Index', (err: Error, data: void) => {
      if (err) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content. Data: %{public}s', JSON.stringify(data));
    });

    // 设置窗口背景色跟随深浅色模式
    windowStage.getMainWindow().then((win: window.Window) => {
      const colorMode = AppStorage.get<ConfigurationConstant.ColorMode>('colorMode') ?? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
      const bgColor = colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#121212' : '#E7F8FC';
      win.setWindowBackgroundColor(bgColor);
      // 设置状态栏背景透明，文字颜色跟随深浅色
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#FFFFFF' : '#14233a'
      });
    });
  }

  onWindowStageDestroy() {
    hilog.info(DOMAIN, TAG, 'EntryAbility onWindowStageDestroy');
  }

  onForeground() {
    hilog.info(DOMAIN, TAG, 'EntryAbility onForeground');
  }

  onBackground() {
    hilog.info(DOMAIN, TAG, 'EntryAbility onBackground');
  }
}
