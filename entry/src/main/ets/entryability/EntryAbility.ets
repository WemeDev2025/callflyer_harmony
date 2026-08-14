import UIAbility from '@ohos.app.ability.UIAbility';
import hilog from '@ohos.hilog';
import window from '@ohos.window';
import Want from '@ohos.app.ability.Want';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
import { Configuration, AbilityConstant } from '@kit.AbilityKit';
import dataPreferences from '@ohos.data.preferences';
import PushService from '../service/PushService';

const TAG = 'EntryAbility';
const DOMAIN = 0x0001;
const PREFS_NAME = 'callflyer_prefs';
const KEY_AGREEMENT_ACCEPTED = 'callflyer_agreement_accepted';
const KEY_NOTIFICATION_REFUSED = 'notification_refused'; // 记录通知权限是否被用户拒绝

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    hilog.info(DOMAIN, TAG, 'EntryAbility onCreate');
    // 从 Preferences 读取协议同意状态，写入 AppStorage 供页面同步读取
    try {
      const prefs = dataPreferences.getPreferencesSync(this.context, { name: PREFS_NAME });
      const accepted = prefs.getSync(KEY_AGREEMENT_ACCEPTED, '') as string;
      hilog.info(DOMAIN, TAG, 'agreement accepted from prefs: %{public}s', accepted);
      AppStorage.setOrCreate<string>(KEY_AGREEMENT_ACCEPTED, accepted);
      // 读取通知权限拒绝状态
      const notificationRefused = prefs.getSync(KEY_NOTIFICATION_REFUSED, false) as boolean;
      AppStorage.setOrCreate<boolean>(KEY_NOTIFICATION_REFUSED, notificationRefused);
      hilog.info(DOMAIN, TAG, 'notification refused from prefs: %{public}s', notificationRefused.toString());
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to read preferences: %{public}s', JSON.stringify(e));
      AppStorage.setOrCreate<string>(KEY_AGREEMENT_ACCEPTED, '');
      AppStorage.setOrCreate<boolean>(KEY_NOTIFICATION_REFUSED, false);
    }
    // 保存当前颜色模式到 AppStorage
    AppStorage.setOrCreate('colorMode', this.context.config.colorMode ?? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);

    // 初始化 PushService 并注册 Push Token（无需登录）
    PushService.getInstance(this.context).getAndRegisterPushToken();
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
        statusBarColor: bgColor,
        statusBarContentColor: colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#FFFFFF' : '#14233a'
      });
    });
  }

  onDestroy() {
    hilog.info(DOMAIN, TAG, 'EntryAbility onDestroy');
  }

  // 请求通知权限
  private async requestNotificationPermission(): Promise<void> {
    // 检查用户是否之前拒绝过通知权限，如果拒绝过则不再弹窗申请
    const wasRefused = AppStorage.get<boolean>(KEY_NOTIFICATION_REFUSED) ?? false;
    if (wasRefused) {
      hilog.info(DOMAIN, TAG, '[ANS] 用户之前已拒绝通知权限，不再弹窗申请');
      return;
    }

    try {
      // 检查当前通知权限状态
      let isEnabled = notificationManager.isNotificationEnabledSync();
      hilog.info(DOMAIN, TAG, '[ANS] 通知权限状态: %{public}s', isEnabled ? '已开启' : '未开启');

      // 已开启则不需要申请
      if (isEnabled) {
        hilog.info(DOMAIN, TAG, '[ANS] 通知权限已开启，无需申请');
        return;
      }

      // 未开启才请求通知权限（系统会弹窗）
      hilog.info(DOMAIN, TAG, '[ANS] 调用 requestEnableNotification...');
      await notificationManager.requestEnableNotification();
      hilog.info(DOMAIN, TAG, '[ANS] requestEnableNotification success');
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, '[ANS] requestEnableNotification failed, code=%{public}d, message=%{public}s', err.code, err.message);

      // 根据错误码处理
      if (err.code === 1600004) {
        // 用户拒绝授权，保存拒绝状态，不再弹窗或打开设置页
        hilog.info(DOMAIN, TAG, '[ANS] 用户拒绝通知权限，保存状态');
        try {
          const prefs = dataPreferences.getPreferencesSync(this.context, { name: PREFS_NAME });
          prefs.putSync(KEY_NOTIFICATION_REFUSED, true);
          prefs.flushSync();
          AppStorage.setOrCreate<boolean>(KEY_NOTIFICATION_REFUSED, true);
          hilog.info(DOMAIN, TAG, '[ANS] 已保存拒绝状态');
        } catch (e) {
          hilog.error(DOMAIN, TAG, '[ANS] 保存拒绝状态失败: %{public}s', JSON.stringify(e));
        }
        // 不再打开通知设置页面，静默处理
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
        statusBarColor: bgColor,
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
