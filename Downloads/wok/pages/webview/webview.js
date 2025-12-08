// pages/webview/webview.js
Page({
  data: {
    url: ''
  },

  onLoad(options) {
    const { url, title } = options
    if (url) {
      const decodedUrl = decodeURIComponent(url)
      console.log('[WebView] 加载URL:', decodedUrl)
      
      // 设置导航栏标题
      if (title) {
        wx.setNavigationBarTitle({
          title: decodeURIComponent(title)
        })
      } else {
        // 尝试从 URL 提取域名作为标题
        try {
          // 小程序环境可能不支持 new URL()，使用正则表达式提取域名
          const match = decodedUrl.match(/https?:\/\/([^\/]+)/)
          if (match && match[1]) {
            const hostname = match[1].replace(/^www\./, '') // 移除 www. 前缀
            wx.setNavigationBarTitle({
              title: hostname
            })
          } else {
            wx.setNavigationBarTitle({
              title: '网页'
            })
          }
        } catch (e) {
          // 解析失败，使用默认标题
          wx.setNavigationBarTitle({
            title: '网页'
          })
        }
      }
      
      this.setData({
        url: decodedUrl
      })
    } else {
      console.error('[WebView] 未提供URL参数')
      wx.showToast({
        title: 'URL参数缺失',
        icon: 'none'
      })
      // 返回上一页
      setTimeout(() => {
        wx.navigateBack()
      }, 1500)
    }
  },

  /**
   * 页面加载错误
   */
  onError(e) {
    console.error('[WebView] 页面加载错误', e)
    wx.showToast({
      title: '页面加载失败',
      icon: 'none'
    })
  },

  /**
   * 页面加载完成
   */
  onLoadComplete(e) {
    console.log('[WebView] 页面加载完成', e)
  }
})

