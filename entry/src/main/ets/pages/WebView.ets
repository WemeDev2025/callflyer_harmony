import web_webview from '@ohos.web.webview';
import router from '@ohos.router';
import window from '@ohos.window';

@Entry
@Component
struct WebView {
  @State url: string = '';
  @State title: string = '';
  controller: web_webview.WebviewController = new web_webview.WebviewController();

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    if (params) {
      this.url = params['url'] || '';
      this.title = params['title'] || this.extractDomain(this.url);
    }
    // 全屏沉浸
    window.getLastWindow(getContext(this)).then((win) => {
      win.setFullScreen(true);
    });
  }

  aboutToDisappear() {
    // 恢复状态栏
    window.getLastWindow(getContext(this)).then((win) => {
      win.setFullScreen(false);
    });
  }

  // 判断是否是 AppGallery 链接（WebView 会白屏）
  private isAppGalleryUrl(url: string): boolean {
    return url.includes('appgallery.huawei.com');
  }

  extractDomain(url: string): string {
    if (!url) return '网页';
    const match = url.match(/https?:\/\/([^\/]+)/);
    return match ? match[1] : '网页';
  }

  build() {
    Stack() {
      if (this.url) {
        Web({ src: this.url, controller: this.controller })
          .width('100%')
          .height('100%')
          .geolocationAccess(true)
          .onPageBegin((event) => {
            const loadingUrl = event.url || '';
            console.info('【WebView】开始加载: ' + loadingUrl);
            // AppGallery 链接直接关闭 WebView，避免白屏
            if (this.isAppGalleryUrl(loadingUrl)) {
              console.info('【WebView】检测到 AppGallery 链接，关闭 WebView');
              router.back();
            }
          })
          .onGeolocationShow((event) => {
            console.info('【WebView】地理位置请求, origin: ' + event.origin);
            event.geolocation.invoke(event.origin, true, false);
          })
          .expandSafeArea([SafeAreaType.SYSTEM])
      } else {
        Column() {
          Text('无效的链接')
            .fontColor('#999999')
            .fontSize(14)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a1a')
    .expandSafeArea([SafeAreaType.SYSTEM])
  }
}
