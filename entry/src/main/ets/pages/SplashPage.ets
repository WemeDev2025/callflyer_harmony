import router from '@ohos.router';
import { fetchConfig } from '../service/ApiService';

/**
 * 开屏页 - Stack 方案
 * 方案二 + 方案六混合：Stack 层叠 + 动画
 *
 * 图层结构：
 * Stack
 * ├── 背景图片（全屏，延伸至安全区域，支持网络图片）
 * ├── 蒙层遮罩（半透明黑色渐变）
 * ├── 品牌 Logo + 标语
 * └── 跳过按钮（右下角）
 */

const COUNTDOWN_SECONDS = 5; // 倒计时秒数

@Entry
@Component
struct SplashPage {
  @State maskOpacity: number = 0; // 蒙层透明度（动画驱动）
  @State logoOpacity: number = 0; // Logo 透明度（动画驱动）
  @State countdown: number = COUNTDOWN_SECONDS;
  @State isShowSplash: boolean = true; // 控制开屏显隐（退出动画用）
  @State adImageUrl: string = ''; // 后端返回的广告图 URL
  private countdownTimer: number = -1;

  aboutToAppear(): void {
    // 加载后端配置
    this.loadAdConfig();
    // 启动开屏动画
    this.startEntranceAnimation();
    // 启动倒计时
    this.startCountdown();
  }

  aboutToDisappear(): void {
    this.stopCountdown();
  }

  /**
   * 加载后端开屏广告配置
   */
  private async loadAdConfig(): Promise<void> {
    try {
      const config = await fetchConfig();
      console.info('【开屏页】fetchConfig result:', JSON.stringify(config));
      console.info('【开屏页】showHarmonyAdImage:', config.showHarmonyAdImage);
      console.info('【开屏页】harmonyAdImageUrl:', config.harmonyAdImageUrl);
      // 如果后端配置了鸿蒙开屏广告图且启用，则使用后端图片
      if (config.showHarmonyAdImage && config.harmonyAdImageUrl) {
        this.adImageUrl = config.harmonyAdImageUrl;
        console.info('【开屏页】使用后端广告图:', this.adImageUrl);
      }
    } catch (e) {
      console.error('【开屏页】加载配置失败:', JSON.stringify(e));
    }
  }

  /**
   * 入场动画：蒙层渐显 + Logo 渐显
   */
  private startEntranceAnimation(): void {
    setTimeout(() => {
      animateToImmediately({
        duration: 600,
        curve: Curve.EaseOut
      }, () => {
        this.maskOpacity = 0.6;
      });

      setTimeout(() => {
        animateToImmediately({
          duration: 800,
          curve: Curve.EaseOut
        }, () => {
          this.logoOpacity = 1;
        });
      }, 200);
    }, 100);
  }

  /**
   * 启动倒计时
   */
  private startCountdown(): void {
    this.countdown = COUNTDOWN_SECONDS;
    this.countdownTimer = setInterval(() => {
      this.countdown--;
      if (this.countdown <= 0) {
        this.stopCountdown();
        this.goToHome();
      }
    }, 1000) as number;
  }

  /**
   * 停止倒计时
   */
  private stopCountdown(): void {
    if (this.countdownTimer >= 0) {
      clearInterval(this.countdownTimer);
      this.countdownTimer = -1;
    }
  }

  /**
   * 跳转首页（带退出动画）
   */
  private goToHome(): void {
    this.stopCountdown();

    // 标记广告已由开屏页展示过，首页不再重复展示
    AppStorage.setOrCreate<boolean>('splash_ad_shown', true);

    animateToImmediately({
      duration: 300,
      curve: Curve.Friction,
      onFinish: () => {
        // 用 replaceUrl 替换当前页，而非 pushUrl——这样返回栈里没有 SplashPage，
        // 用户按返回键时直接退出应用，而非回到开屏页
        router.replaceUrl({
          url: 'pages/Index'
        });
      }
    }, () => {
      this.maskOpacity = 0;
      this.logoOpacity = 0;
      this.isShowSplash = false;
    });
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      // ========== 底层：背景图片（延伸至安全区域） ==========
      if (this.adImageUrl) {
        // 后端配置了广告图，使用网络图片
        Image(this.adImageUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      } else {
        // 使用本地启动图
        Image($r('app.media.icon_startwindow'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }

      // ========== 上层：蒙层 + 内容 ==========
      if (this.isShowSplash) {
        // 蒙层容器（延伸至安全区域）
        Column()
          .width('100%')
          .height('100%')
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

        // ① 蒙层遮罩（半透明黑色）
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#000000')
          .opacity(this.maskOpacity)
          .animation({
            duration: 600,
            curve: Curve.EaseOut
          })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

        // ② 品牌 Logo 区域（居中偏上）
        Column({
          space: 20
        }) {
          Image($r('app.media.icon_alert'))
            .width(80)
            .height(80)
            .objectFit(ImageFit.Contain)
            .opacity(this.logoOpacity)
            .animation({
              duration: 800,
              curve: Curve.EaseOut
            })

          Text('呼叫飞手')
            .fontSize(28)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
            .opacity(this.logoOpacity)
            .animation({
              duration: 800,
              curve: Curve.EaseOut
            })

          Text('职业飞手 一键呼叫')
            .fontSize(14)
            .fontColor('rgba(255, 255, 255, 0.8)')
            .opacity(this.logoOpacity)
            .animation({
              duration: 800,
              curve: Curve.EaseOut
            })
        }
        .opacity(this.logoOpacity)
        .animation({
          duration: 800,
          curve: Curve.EaseOut
        })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .position({
          x: '50%',
          y: '35%'
        })
        .translate({
          x: '-50%'
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }

      // ========== 跳过按钮（右下角，延伸至安全区域）==========
      if (this.isShowSplash) {
        Column() {
          Row({
            space: 4
          }) {
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
        .border({
          width: 1,
          color: 'rgba(255, 255, 255, 0.25)'
        })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .margin({
          bottom: 56,
          right: 16
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick(() => {
          this.stopCountdown();
          this.goToHome();
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
