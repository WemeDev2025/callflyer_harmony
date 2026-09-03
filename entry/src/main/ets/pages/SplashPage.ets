import router from '@ohos.router';
import { fetchConfig } from '../service/ApiService';
import dataPreferences from '@ohos.data.preferences';
import window from '@ohos.window';
import { Want, common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

// Preferences / AppStorage 键名（与 EntryAbility 保持一致）
const PREFS_NAME = 'callflyer_prefs';
const KEY_FIRST_LAUNCH_DONE = 'first_launch_done';
const KEY_SHOW_HARMONY_AD = 'show_harmony_ad';
const KEY_AD_IMAGE_URL = 'harmony_ad_image_url';
const KEY_AD_CLICK_TYPE = 'harmony_ad_click_type';
const KEY_AD_CLICK_PAGE = 'harmony_ad_click_page';
const KEY_AD_CLICK_URL = 'harmony_ad_click_url';

/**
 * 开屏广告页
 *
 * 新逻辑：
 *   1. 从 AppStorage 读取上次缓存的广告图参数，立即展示（无需等待网络）。
 *   2. 后台异步拉取最新配置，仅将结果写入 Preferences / AppStorage 缓存，
 *      供"下次启动"使用——本次展示内容不受影响。
 *   3. 首次安装时 EntryAbility 不会路由到此页，故此页无需处理"无缓存"情况。
 */
@Entry
@Component
struct SplashPage {
  @State countdown: number = 5;
  @State adImageOpacity: number = 0;
  @State adImageUrl: string = '';
  @State adClickType: string = 'none';
  @State adClickPage: string = '';
  @State adClickUrl: string = '';
  private countdownTimer: number = -1;

  aboutToAppear(): void {
    // 0. 开屏页独占全屏（状态栏 + 导航栏都被内容覆盖）
    window.getLastWindow(getContext(this)).then((win) => {
      win.setWindowLayoutFullScreen(true).then(() => {
        console.info('【SplashPage】setWindowLayoutFullScreen(true) 成功');
      }).catch((e: Error) => {
        console.error('【SplashPage】setWindowLayoutFullScreen(true) 失败:', JSON.stringify(e));
      });
      // 隐藏状态栏（透明背景融入黑色）
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: '#00000000'
      }).catch((e: Error) => {
        console.error('【SplashPage】setWindowSystemBarProperties 失败:', JSON.stringify(e));
      });
    }).catch((e: Error) => {
      console.error('【SplashPage】getLastWindow 失败:', JSON.stringify(e));
    });

    // 1. 从缓存立即读取广告图参数
    this.adImageUrl = AppStorage.get<string>(KEY_AD_IMAGE_URL) ?? '';
    this.adClickType = AppStorage.get<string>(KEY_AD_CLICK_TYPE) ?? 'none';
    this.adClickPage = AppStorage.get<string>(KEY_AD_CLICK_PAGE) ?? '';
    this.adClickUrl = AppStorage.get<string>(KEY_AD_CLICK_URL) ?? '';
    console.info('【开屏页】从缓存读取广告图: url=' + this.adImageUrl + ' clickType=' + this.adClickType);

    // 2. 广告图淡入
    setTimeout(() => {
      animateToImmediately({ duration: 400, curve: Curve.EaseOut }, () => {
        this.adImageOpacity = 1;
      });
    }, 100);

    // 3. 启动倒计时
    this.startCountdown();

    // 4. 后台静默拉取最新配置，只写缓存，不影响本次展示
    this.refreshConfigCache();
  }

  aboutToDisappear(): void {
    this.stopCountdown();
    // 恢复窗口状态：非全屏 + 显示导航栏 + 状态栏颜色跟随深浅色
    window.getLastWindow(getContext(this)).then((win) => {
      win.setWindowLayoutFullScreen(false).then(() => {
        console.info('【SplashPage】aboutToDisappear: setWindowLayoutFullScreen(false) 成功');
      }).catch((e: Error) => {
        console.error('【SplashPage】aboutToDisappear: setWindowLayoutFullScreen(false) 失败:', JSON.stringify(e));
      });
      win.setSpecificSystemBarEnabled('navigationIndicator', true);
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: '#14233a'
      });
    }).catch((e: Error) => {
      console.error('【SplashPage】aboutToDisappear: getLastWindow 失败:', JSON.stringify(e));
    });
  }

  // ─── 倒计时 ──────────────────────────────────────────────────────────────────

  private startCountdown(): void {
    this.countdown = 5;
    this.countdownTimer = setInterval(() => {
      this.countdown -= 1;
      if (this.countdown <= 0) {
        this.stopCountdown();
        this.goToHome();
      }
    }, 1000) as number;
  }

  private stopCountdown(): void {
    if (this.countdownTimer >= 0) {
      clearInterval(this.countdownTimer);
      this.countdownTimer = -1;
    }
  }

  // ─── 后台刷新缓存（本次展示不受影响）────────────────────────────────────────

  private async refreshConfigCache(): Promise<void> {
    try {
      const config = await fetchConfig();
      const showAd = config.showHarmonyAdImage ?? false;
      const imageUrl = config.harmonyAdImageUrl ?? '';
      const clickType = config.harmonyAdClickType ?? 'none';
      const clickPage = config.harmonyAdClickPage ?? '';
      const clickUrl = config.harmonyAdClickUrl ?? '';

      console.info('【开屏页】后台刷新配置缓存: show=' + String(showAd) + ' url=' + imageUrl);

      // 更新 AppStorage（供下次启动 EntryAbility 读取路由决策用）
      AppStorage.setOrCreate<boolean>(KEY_SHOW_HARMONY_AD, showAd);
      AppStorage.setOrCreate<string>(KEY_AD_IMAGE_URL, imageUrl);
      AppStorage.setOrCreate<string>(KEY_AD_CLICK_TYPE, clickType);
      AppStorage.setOrCreate<string>(KEY_AD_CLICK_PAGE, clickPage);
      AppStorage.setOrCreate<string>(KEY_AD_CLICK_URL, clickUrl);

      // 持久化到 Preferences
      const prefs = dataPreferences.getPreferencesSync(getContext(this), { name: PREFS_NAME });
      prefs.putSync(KEY_SHOW_HARMONY_AD, showAd);
      prefs.putSync(KEY_AD_IMAGE_URL, imageUrl);
      prefs.putSync(KEY_AD_CLICK_TYPE, clickType);
      prefs.putSync(KEY_AD_CLICK_PAGE, clickPage);
      prefs.putSync(KEY_AD_CLICK_URL, clickUrl);
      prefs.flushSync();
    } catch (e) {
      // 网络失败：缓存保持原值，下次启动依然使用旧缓存，静默处理
      console.warn('【开屏页】后台刷新配置失败（缓存保持不变）:', JSON.stringify(e));
    }
  }

  // ─── 路由跳转 ────────────────────────────────────────────────────────────────

  private goToHome(): void {
    this.stopCountdown();
    router.replaceUrl({ url: 'pages/Index' });
  }

  // 判断是否是 AppGallery 链接（WebView 会白屏）
  private isAppGalleryUrl(url: string): boolean {
    return url.includes('appgallery.huawei.com');
  }

  // 用系统浏览器打开链接
  private openInBrowser(url: string): void {
    console.info('【开屏页】用系统浏览器打开:', url);
    const wantInfo: Want = {
      action: 'ohos.want.action.viewData',
      uri: url
    };
    try {
      const context = getContext(this) as common.UIAbilityContext;
      context.startAbility(wantInfo, (err: BusinessError) => {
        if (err) {
          console.error('【开屏页】浏览器打开失败:', JSON.stringify(err));
          router.pushUrl({ url: 'pages/WebView', params: { url: url, title: '网页' } });
        }
      });
    } catch (e) {
      console.error('【开屏页】系统浏览器异常:', JSON.stringify(e));
      router.pushUrl({ url: 'pages/WebView', params: { url: url, title: '网页' } });
    }
  }

  private handleAdClick(): void {
    if (this.adClickType === 'none') {
      return;
    }
    this.stopCountdown();
    if (this.adClickType === 'page' && this.adClickPage) {
      this.goToHome();
      setTimeout(() => {
        router.pushUrl({ url: this.adClickPage });
      }, 50);
    } else if (this.adClickType === 'url' && this.adClickUrl) {
      if (this.isAppGalleryUrl(this.adClickUrl)) {
        // AppGallery 链接：先关闭 SplashPage，再启动浏览器
        // 避免从浏览器返回时看到白屏
        this.goToHome();
        setTimeout(() => {
          this.openInBrowser(this.adClickUrl);
        }, 50);
      } else {
        this.goToHome();
        setTimeout(() => {
          router.pushUrl({ url: 'pages/WebView', params: { url: this.adClickUrl, title: '网页' } });
        }, 50);
      }
    }
  }

  // ─── UI ──────────────────────────────────────────────────────────────────────

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      // 底层：纯黑背景
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')

      // 广告图（从缓存 URL 加载，淡入展示）
      if (this.adImageUrl) {
        Column() {
          Image(this.adImageUrl)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
        }
        .width('100%')
        .height('100%')
        .opacity(this.adImageOpacity)
        .onClick(() => {
          this.handleAdClick();
        })
      }

      // 跳过按钮（右下角）
      Column() {
        Row({ space: 4 }) {
          Text('跳过')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .fontWeight(400)
          Text(this.countdown.toString())
            .fontSize(14)
            .fontColor('rgba(255,255,255,0.7)')
            .fontWeight(400)
        }
      }
      .width(72)
      .height(36)
      .backgroundColor('rgba(0,0,0,0.45)')
      .borderRadius(18)
      .border({ width: 1, color: 'rgba(255,255,255,0.25)' })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ bottom: 18, right: 18 })
      .onClick(() => {
        this.stopCountdown();
        this.goToHome();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT, SafeAreaType.KEYBOARD],
      [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END]);
  }
}
