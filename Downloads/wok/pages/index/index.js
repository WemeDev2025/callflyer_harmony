// pages/index/index.js
Page({
  data: {
    userInfo: null,
    animationClass: 'cooking'  // 动画类名：'cooking' 表示炒菜动画
  },

  onLoad() {
    this.loadUserInfo()
    // 页面加载时启动动画
    this.startAnimation()
  },

  onShow() {
    // 每次显示页面时刷新用户信息
    this.loadUserInfo()
    // 重新启动动画
    this.startAnimation()
  },

  onHide() {
    // 页面隐藏时停止动画（可选）
    // this.stopAnimation()
  },

  /**
   * 启动炒锅旋转动画
   */
  startAnimation() {
    // 确保动画类名已设置
    this.setData({
      animationClass: 'cooking'
    })
  },

  /**
   * 停止动画（如果需要）
   */
  stopAnimation() {
    this.setData({
      animationClass: ''
    })
  },

  /**
   * 加载用户信息
   */
  loadUserInfo() {
    const app = getApp()
    if (app.globalData && app.globalData.userInfo) {
      this.setData({
        userInfo: app.globalData.userInfo
      })
    }
  },

  /**
   * 跳转到个人资料页面
   */
  goToProfile() {
    wx.navigateTo({
      url: '/pages/profile/profile'
    })
  }
})

