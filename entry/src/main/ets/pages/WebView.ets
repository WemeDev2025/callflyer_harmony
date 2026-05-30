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
