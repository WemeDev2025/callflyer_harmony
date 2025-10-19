// pages/index/index.js
const app = getApp();

Page({
  data: {
    userInfo: {},
    hasUserInfo: false,
    isLoggedIn: false
  },

  onLoad() {
    // 页面加载时的初始化
    this.checkLoginStatus();
  },

  onShow() {
    // 页面显示时检查登录状态
    this.checkLoginStatus();
  },

  // 检查登录状态
  checkLoginStatus() {
    const userInfo = app.getUserInfo();
    const isLoggedIn = app.isLoggedIn();
    
    this.setData({
      userInfo: userInfo || {},
      hasUserInfo: !!userInfo,
      isLoggedIn: isLoggedIn
    });
  },

  // 服务卡片点击事件
  onServiceTap(e) {
    const type = e.currentTarget.dataset.type;
    
    switch(type) {
        case 'elderly':
          wx.navigateTo({
            url: '/pages/elderly/elderly'
          });
          break;
      case 'work':
        wx.navigateTo({
          url: '/pages/work-card/work-card'
        });
        break;
      case 'hire':
        wx.navigateTo({
          url: '/pages/hire/hire'
        });
        break;
      case 'business':
        wx.showToast({
          title: '功能开发中',
          icon: 'none'
        });
        break;
      case 'account':
        wx.showToast({
          title: '我的账号功能开发中',
          icon: 'none'
        });
        break;
      default:
        break;
    }
  },

  // 轮播图点击事件
  onBannerTap() {
    // 跳转到本地文章页面
    wx.navigateTo({
      url: '/pages/article/article'
    });
  },

  // 手动刷新登录状态
  async refreshLoginStatus() {
    try {
      wx.showLoading({ title: '刷新中...' });
      
      const result = await app.refreshUserInfo();
      
      if (result.success) {
        this.checkLoginStatus();
        wx.showToast({
          title: '刷新成功',
          icon: 'success'
        });
      } else {
        wx.showToast({
          title: result.message || '刷新失败',
          icon: 'none'
        });
      }
    } catch (error) {
      console.error('刷新登录状态失败:', error);
      wx.showToast({
        title: '刷新失败',
        icon: 'none'
      });
    } finally {
      wx.hideLoading();
    }
  },

  // 用户登出
  logout() {
    wx.showModal({
      title: '确认登出',
      content: '确定要登出当前账号吗？',
      success: (res) => {
        if (res.confirm) {
          app.logout();
          this.checkLoginStatus();
          wx.showToast({
            title: '已登出',
            icon: 'success'
          });
        }
      }
    });
  }

})
