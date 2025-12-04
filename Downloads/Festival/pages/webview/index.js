// pages/webview/index.js
Page({
  data: {
    url: '' // 要加载的网页URL
  },

  onLoad(options) {
    console.log('[WebView] 页面加载', options);
    
    // 从URL参数中获取要加载的网页地址
    if (options.url) {
      const decodedUrl = decodeURIComponent(options.url);
      console.log('[WebView] 加载URL:', decodedUrl);
      this.setData({
        url: decodedUrl
      });
    } else {
      console.error('[WebView] URL参数为空');
      wx.showToast({
        title: 'URL参数错误',
        icon: 'none'
      });
      // 延迟返回上一页
      setTimeout(() => {
        wx.navigateBack();
      }, 1500);
    }
  },

  onMessage(e) {
    // 接收来自 web-view 的消息
    console.log('[WebView] 收到消息', e.detail.data);
  },

  onError(e) {
    console.error('[WebView] 加载失败', e);
    wx.showToast({
      title: '网页加载失败',
      icon: 'none'
    });
  }
});




