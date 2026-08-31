import window from '@ohos.window';
import router from '@ohos.router';

// AppStorage keys（与 Index.ets 保持一致）
const AD_IMAGE_URL_KEY = 'splashAdImageUrl';
const AD_CLICK_TYPE_KEY = 'splashAdClickType';
const AD_CLICK_PAGE_KEY = 'splashAdClickPage';
const AD_CLICK_URL_KEY = 'splashAdClickUrl';

const AD_DISPLAY_DURATION = 5000; // 广告最长展示时长（ms）

@Entry
@Component
struct SplashAdPage {
  @State adImageUrl: string = '';
  @State adImageOpacity: number = 0;
  @State countdown: number = 5; // 倒计时秒数
  @State adClickType: string = 'none';
  @State adClickPage: string = '';
  @State adClickUrl: string = '';
  private displayTimer: number = -1;
  private countdownTimer: number = -1;
  private startTime: number = 0;

  aboutToAppear() {
    // 从 AppStorage 读取广告参数
    this.adImageUrl = AppStorage.get<string>(AD_IMAGE_URL_KEY) ?? '';
    this.adClickType = AppStorage.get<string>(AD_CLICK_TYPE_KEY) ?? 'none';
    this.adClickPage = AppStorage.get<string>(AD_CLICK_PAGE_KEY) ?? '';
    this.adClickUrl = AppStorage.get<string>(AD_CLICK_URL_KEY) ?? '';
    console.info('【开屏广告】SplashAdPage 数据: imageUrl=' + this.adImageUrl + ', clickType=' + this.adClickType + ', clickPage=' + this.adClickPage + ', clickUrl=' + this.adClickUrl);

    // 启动倒计时
    this.startTime = Date.now();
    this.startCountdown();

    // 淡入动画
    setTimeout(() => {
      animateToImmediately({ duration: 400, curve: Curve.EaseOut }, () => {
        this.adImageOpacity = 1;
      });
    }, 100);
  }

  aboutToDisappear() {
    this.clearTimers();
  }

  private clearTimers() {
    if (this.displayTimer >= 0) {
      clearTimeout(this.displayTimer);
      this.displayTimer = -1;
    }
    if (this.countdownTimer >= 0) {
      clearInterval(this.countdownTimer);
      this.countdownTimer = -1;
    }
  }

  private startCountdown() {
    this.countdown = Math.ceil(AD_DISPLAY_DURATION / 1000);

    this.countdownTimer = setInterval(() => {
      this.countdown -= 1;
      if (this.countdown <= 0) {
        this.clearTimers();
        this.closeAd();
      }
    }, 1000) as number;
  }

  private async closeAd() {
    console.info('【开屏广告】关闭子窗口');
    try {
      const win = await window.getLastWindow(getContext(this));
      win.destroyWindow();
    } catch (e) {
      console.error('【开屏广告】关闭失败:', JSON.stringify(e));
    }
  }

  // 处理广告点击事件，对齐后端点击行为
  private handleAdClick(): void {
    const clickType = this.adClickType;
    console.info('【开屏广告】点击广告, clickType=' + clickType);
    if (clickType === 'none') {
      return;
    }
    this.clearTimers();
    if (clickType === 'page' && this.adClickPage) {
      // 跳转内部页面
      console.info('【开屏广告】跳转页面:', this.adClickPage);
      this.closeAd();
      setTimeout(() => {
        router.pushUrl({ url: this.adClickPage });
      }, 50);
    } else if (clickType === 'url' && this.adClickUrl) {
      // 跳转外部链接：先关广告窗口，再在主页导航栈上打开 WebView
      console.info('【开屏广告】跳转链接:', this.adClickUrl);
      this.closeAd();
      setTimeout(() => {
        router.pushUrl({ url: 'pages/WebView', params: { url: this.adClickUrl, title: '网页' } });
      }, 100);
    }
  }

  build() {
    // 根节点撑满整个窗口（子窗口已经是全屏，无需 expandSafeArea）
    Stack({ alignContent: Alignment.TopEnd }) {

      // 全屏黑色背景蒙层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')

      // 广告图居中显示
      if (this.adImageUrl) {
        Column() {
          Image(this.adImageUrl)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .opacity(this.adImageOpacity)
        }
        .width('100%')
        .height('100%')
        .onClick(() => {
          this.handleAdClick();
        })
      }

      // 跳过按钮（右上角，固定 margin 即可，无安全区问题）
      Column() {
        Row() {
          Text('跳过')
            .fontSize(13)
            .fontColor('#FFFFFF')
            .fontWeight(400)
          Text(' ' + this.countdown)
            .fontSize(13)
            .fontColor('rgba(255,255,255,0.6)')
            .fontWeight(400)
        }
      }
      .width(72)
      .height(32)
      .backgroundColor('rgba(0, 0, 0, 0.45)')
      .borderRadius(16)
      .border({ width: 1, color: 'rgba(255,255,255,0.2)' })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 56, right: 16 })
      .onClick(() => {
        this.clearTimers();
        this.closeAd();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }
}
