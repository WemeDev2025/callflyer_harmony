Page({
  data: {
    images: [],
    current: 0,
    menuButtonTop: 0,
    menuButtonHeight: 0
  },
  onLoad(options) {
    let images = [];
    let current = 0;
    try {
      images = JSON.parse(decodeURIComponent(options.images || '[]'));
      current = Number(options.current) || 0;
    } catch (e) {}
    const mb = wx.getMenuButtonBoundingClientRect();
    this.setData({ images, current, menuButtonTop: mb.top, menuButtonHeight: mb.height });
  },
  onSwiperChange(e) {
    this.setData({ current: e.detail.current });
  },
  goBack() {
    wx.navigateBack({ delta: 1 });
  },
  onDownload() {
    const url = this.data.images[this.data.current];
    const that = this;
    // 动态引入图片缓存工具
    const imageCache = require('../../utils/imageCache.js');
    wx.showLoading({ title: '正在保存...' });
    imageCache.downloadAndCacheImage(url)
      .then(localPath => {
        wx.saveImageToPhotosAlbum({
          filePath: localPath,
          success: () => {
            wx.showToast({ title: '已保存到相册', icon: 'success' });
          },
          fail: (err) => {
            wx.showToast({ title: '保存失败', icon: 'none' });
            console.error('保存图片失败', err);
          },
          complete: () => {
            wx.hideLoading();
          }
        });
      })
      .catch(err => {
        wx.showToast({ title: '下载失败', icon: 'none' });
        wx.hideLoading();
        console.error('下载图片失败', err);
      });
  },
  onUse() {
    const url = this.data.images[this.data.current];
    // 设置全局 pendingBgUrl，课程表页面 onShow 时会自动应用
    const app = getApp();
    app.globalData.pendingBgUrl = url;
    wx.showToast({ title: '已应用', icon: 'success' });
    // 延迟跳转回课程表页面
    setTimeout(() => {
      wx.navigateBack({ delta: 1 });
    }, 600);
  }
});