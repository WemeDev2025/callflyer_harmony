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
const KEY_SHOW_HARMONY_AD = 'show_harmony_ad';           // 缓存广告开关（bool）
const KEY_AD_IMAGE_URL = 'harmony_ad_image_url';         // 缓存广告图 URL
const KEY_AD_CLICK_TYPE = 'harmony_ad_click_type';       // 缓存点击行为
const KEY_AD_CLICK_PAGE = 'harmony_ad_click_page';       // 缓存内部页面路径
const KEY_AD_CLICK_URL = 'harmony_ad_click_url';         // 缓存外部链接
const KEY_FIRST_LAUNCH_DONE = 'first_launch_done';       // 是否已完成首次启动（首装标记）

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    hilog.info(DOMAIN, TAG, 'EntryAbility onCreate');

    // 从 Preferences 一次性读取所有持久化状态
    try {
      const prefs = dataPreferences.getPreferencesSync(this.context, { name: PREFS_NAME });

      // 用户协议同意状态
      const accepted = prefs.getSync(KEY_AGREEMENT_ACCEPTED, '') as string;
      hilog.info(DOMAIN, TAG, 'agreement accepted from prefs: %{public}s', accepted);
      AppStorage.setOrCreate<string>(KEY_AGREEMENT_ACCEPTED, accepted);

      // 通知权限拒绝状态
      const notificationRefused = prefs.getSync(KEY_NOTIFICATION_REFUSED, false) as boolean;
      AppStorage.setOrCreate<boolean>(KEY_NOTIFICATION_REFUSED, notificationRefused);
      hilog.info(DOMAIN, TAG, 'notification refused from prefs: %{public}s', notificationRefused.toString());

      // 首次安装标记（不存在 = 首次安装）
      const firstLaunchDone = prefs.getSync(KEY_FIRST_LAUNCH_DONE, false) as boolean;
      AppStorage.setOrCreate<boolean>(KEY_FIRST_LAUNCH_DONE, firstLaunchDone);
      hilog.info(DOMAIN, TAG, 'firstLaunchDone: %{public}s', String(firstLaunchDone));

      // 广告缓存（完整参数）
      const showHarmonyAd = prefs.getSync(KEY_SHOW_HARMONY_AD, false) as boolean;
      const adImageUrl = prefs.getSync(KEY_AD_IMAGE_URL, '') as string;
      const adClickType = prefs.getSync(KEY_AD_CLICK_TYPE, 'none') as string;
      const adClickPage = prefs.getSync(KEY_AD_CLICK_PAGE, '') as string;
      const adClickUrl = prefs.getSync(KEY_AD_CLICK_URL, '') as string;
      AppStorage.setOrCreate<boolean>(KEY_SHOW_HARMONY_AD, showHarmonyAd);
      AppStorage.setOrCreate<string>(KEY_AD_IMAGE_URL, adImageUrl);
      AppStorage.setOrCreate<string>(KEY_AD_CLICK_TYPE, adClickType);
      AppStorage.setOrCreate<string>(KEY_AD_CLICK_PAGE, adClickPage);
      AppStorage.setOrCreate<string>(KEY_AD_CLICK_URL, adClickUrl);
      hilog.info(DOMAIN, TAG, 'cached ad: show=%{public}s url=%{public}s', String(showHarmonyAd), adImageUrl);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to read preferences: %{public}s', JSON.stringify(e));
      AppStorage.setOrCreate<string>(KEY_AGREEMENT_ACCEPTED, '');
      AppStorage.setOrCreate<boolean>(KEY_NOTIFICATION_REFUSED, false);
      AppStorage.setOrCreate<boolean>(KEY_FIRST_LAUNCH_DONE, false);
      AppStorage.setOrCreate<boolean>(KEY_SHOW_HARMONY_AD, false);
      AppStorage.setOrCreate<string>(KEY_AD_IMAGE_URL, '');
      AppStorage.setOrCreate<string>(KEY_AD_CLICK_TYPE, 'none');
      AppStorage.setOrCreate<string>(KEY_AD_CLICK_PAGE, '');
      AppStorage.setOrCreate<string>(KEY_AD_CLICK_URL, '');
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

    // 路由决策：
    //   首次安装（first_launch_done = false） → 直接加载首页，后台由 Index 拉取并缓存配置
    //   非首次安装，有缓存广告图且开关开启   → 加载开屏页，从缓存直接展示广告图
    //   其他（无广告图 / 开关关闭）          → 直接加载首页
    const firstLaunchDone = AppStorage.get<boolean>(KEY_FIRST_LAUNCH_DONE) ?? false;
    const showHarmonyAd = AppStorage.get<boolean>(KEY_SHOW_HARMONY_AD) ?? false;
    const cachedAdImageUrl = AppStorage.get<string>(KEY_AD_IMAGE_URL) ?? '';
    const hasCachedAd = firstLaunchDone && showHarmonyAd && cachedAdImageUrl.length > 0;
    const startPage = hasCachedAd ? 'pages/SplashPage' : 'pages/Index';
    hilog.info(DOMAIN, TAG,
      'firstLaunchDone=%{public}s showHarmonyAd=%{public}s cachedAdUrl=%{public}s → loading: %{public}s',
      String(firstLaunchDone), String(showHarmonyAd), cachedAdImageUrl, startPage);
    windowStage.loadContent(startPage, (err: Error, data: void) => {
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
