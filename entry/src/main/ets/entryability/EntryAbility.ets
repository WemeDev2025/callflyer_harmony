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
    const colorMode = newConfig.colorMode ?? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    AppStorage.setOrCreate('colorMode', colorMode);

    // 更新窗口背景色和状态栏（跟随深浅色模式切换）
    window.getLastWindow(this.context).then((win: window.Window) => {
      const bgColor = colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#121212' : '#E7F8FC';
      win.setWindowBackgroundColor(bgColor);
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#FFFFFF' : '#14233a'
      });
    });
  }

  onDestroy() {
    hilog.info(DOMAIN, TAG, 'EntryAbility onDestroy');
  }

  // 请求通知权限
  private async requestNotificationPermission(): Promise<void> {
    try {
      // 检查当前通知权限状态
      let isEnabled = notificationManager.isNotificationEnabledSync();
      hilog.info(DOMAIN, TAG, '[ANS] 通知权限状态: %{public}s', isEnabled ? '已开启' : '未开启');

      // 直接请求通知权限（系统会自动处理：已开启则不弹窗，未开启则弹窗）
      hilog.info(DOMAIN, TAG, '[ANS] 调用 requestEnableNotification...');
      await notificationManager.requestEnableNotification();
      hilog.info(DOMAIN, TAG, '[ANS] requestEnableNotification success');
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, '[ANS] requestEnableNotification failed, code=%{public}d, message=%{public}s', err.code, err.message);

      // 根据错误码处理
      if (err.code === 1600004) {
        // 用户拒绝授权，拉起通知设置页面
        hilog.info(DOMAIN, TAG, '[ANS] 用户拒绝，打开通知设置页面');
        try {
          notificationManager.openNotificationSettings(this.context);
        } catch (e) {
          hilog.error(DOMAIN, TAG, '[ANS] openNotificationSettings failed');
        }
      } else if (err.code === 1600013) {
        // 1600013: 渲染异常，延迟重试
        hilog.warn(DOMAIN, TAG, '[ANS] 1600013 渲染异常，1秒后重试');
        setTimeout(() => {
          this.requestNotificationPermission();
        }, 1000);
      }
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    hilog.info(DOMAIN, TAG, 'EntryAbility onWindowStageCreate');

    // 设置窗口背景色跟随深浅色模式
    windowStage.getMainWindow().then((win: window.Window) => {
      const colorMode = AppStorage.get<ConfigurationConstant.ColorMode>('colorMode') ?? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
      const bgColor = colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#121212' : '#E7F8FC';
      win.setWindowBackgroundColor(bgColor);
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#FFFFFF' : '#14233a'
      });
    });

    // 在 UI 加载完成后请求通知权限
    windowStage.loadContent('pages/Index', (err: Error, data: void) => {
      let errCode = (err as BusinessError).code;
      if (err && errCode !== 0) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content. Data: %{public}s', JSON.stringify(data));
      // UI加载完成后请求通知权限
      this.requestNotificationPermission();
    });
  }

  onWindowStageDestroy() {
    hilog.info(DOMAIN, TAG, 'EntryAbility onWindowStageDestroy');
  }

  onForeground() {
    hilog.info(DOMAIN, TAG, 'EntryAbility onForeground');
    AppStorage.setOrCreate('appIsForeground', true);
  }

  onBackground() {
    hilog.info(DOMAIN, TAG, 'EntryAbility onBackground');
    AppStorage.setOrCreate('appIsForeground', false);
  }
}
