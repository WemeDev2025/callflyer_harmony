import router from '@ohos.router';
import { fetchConfig } from '../service/ApiService';

/**
 * 开屏页
 * 结构：图片（全屏，淡入动画）+ 跳过按钮（右下角）
 */

const COUNTDOWN_SECONDS = 5;

@Entry
@Component
struct SplashPage {
  @State countdown: number = COUNTDOWN_SECONDS;
  @State isShowSplash: boolean = true;
  @State adImageUrl: string = '';
  @State imageOpacity: number = 0; // 图片淡入动画
  @State harmonyAdClickType: string = 'none';
  @State harmonyAdClickPage: string = '';
  @State harmonyAdClickUrl: string = '';
  private countdownTimer: number = -1;

  aboutToAppear(): void {
    this.loadAdConfig().then(() => {
      this.startCountdown();
    });
  }

  aboutToDisappear(): void {
    this.stopCountdown();
  }

  private async loadAdConfig(): Promise<void> {
    try {
      const config = await fetchConfig();
      console.info('【开屏页】fetchConfig result:', JSON.stringify(config));
      console.info('【开屏页】showHarmonyAdImage:', config.showHarmonyAdImage);
      console.info('【开屏页】harmonyAdImageUrl:', config.harmonyAdImageUrl);
      if (config.showHarmonyAdImage && config.harmonyAdImageUrl) {
        this.adImageUrl = config.harmonyAdImageUrl;
        this.harmonyAdClickType = config.harmonyAdClickType || 'none';
        this.harmonyAdClickPage = config.harmonyAdClickPage || '';
        this.harmonyAdClickUrl = config.harmonyAdClickUrl || '';
        console.info('【开屏页】使用后端广告图:', this.adImageUrl);
        console.info('【开屏页】点击类型:', this.harmonyAdClickType, '页面:', this.harmonyAdClickPage, '链接:', this.harmonyAdClickUrl);
      }
    } catch (e) {
      console.error('【开屏页】加载配置失败:', JSON.stringify(e));
    }
  }

  private startCountdown(): void {
    // 延迟淡入动画
    setTimeout(() => {
      animateToImmediately({
        duration: 600,
        curve: Curve.EaseOut
      }, () => {
        this.imageOpacity = 1;
      });
    }, 100);

    this.countdown = COUNTDOWN_SECONDS;
    this.countdownTimer = setInterval(() => {
      this.countdown--;
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

  private goToHome(): void {
    this.stopCountdown();
    AppStorage.setOrCreate<boolean>('splash_ad_shown', true);

    // 淡出动画
    animateToImmediately({
      duration: 300,
      curve: Curve.Friction
    }, () => {
      this.imageOpacity = 0;
    });

    setTimeout(() => {
      router.replaceUrl({ url: 'pages/Index' });
    }, 300);
  }

  private handleAdClick(): void {
    const clickType = this.harmonyAdClickType;
    if (clickType === 'none') {
      return;
    }
    this.stopCountdown();
    if (clickType === 'page' && this.harmonyAdClickPage) {
      // 先替换掉开屏页，再跳转目标页面，避免 back 回来看见开屏图
      this.goToHome();
      setTimeout(() => {
        router.pushUrl({ url: this.harmonyAdClickPage });
      }, 350);
    } else if (clickType === 'url' && this.harmonyAdClickUrl) {
      // 先替换掉开屏页，再打开 WebView
      this.goToHome();
      setTimeout(() => {
        router.pushUrl({ url: 'pages/WebView', params: { url: this.harmonyAdClickUrl, title: '网页' } });
      }, 350);
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      // 底层：背景图片（淡入动画）
      if (this.adImageUrl) {
        Image(this.adImageUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .opacity(this.imageOpacity)
          .animation({ duration: 600, curve: Curve.EaseOut })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .onClick(() => {
            this.handleAdClick();
          });
      } else {
        Image($r('app.media.icon_startwindow'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .opacity(this.imageOpacity)
          .animation({ duration: 600, curve: Curve.EaseOut })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .onClick(() => {
            this.handleAdClick();
          });
      }

      // 跳过按钮（右下角）
      if (this.isShowSplash) {
        Column() {
          Row({ space: 4 }) {
            Text('跳过')
              .fontSize(14)
              .fontColor('#FFFFFF')
              .fontWeight(400)
            Text(this.countdown.toString())
              .fontSize(14)
              .fontColor('rgba(255, 255, 255, 0.7)')
              .fontWeight(400)
          }
        }
        .width(72)
        .height(36)
        .backgroundColor('rgba(0, 0, 0, 0.45)')
        .borderRadius(18)
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.25)' })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 56, right: 16 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick(() => {
          this.stopCountdown();
          this.goToHome();
        });
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
  }
}
