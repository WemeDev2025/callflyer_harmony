// pages/index/index.js
const app = getApp();
const dataManager = require('../../utils/dataManager');

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
        // 检查是否已有工作卡，如果有则进入编辑模式
        this.checkWorkCardAndNavigate();
        break;
      case 'hire':
        // 默认打开编辑需求页面
        wx.navigateTo({
          url: '/pages/hire/hire?edit=true'
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

  // 检查工作卡并导航
  async checkWorkCardAndNavigate() {
    try {
      // 显示加载提示
      wx.showLoading({
        title: '检查工作卡...',
        mask: true
      });

      // 检查是否已有工作卡
      const result = await dataManager.workCard.getMy();
      
      if (result.success && result.data) {
        // 已有工作卡，进入编辑模式
        console.log('✅ 检测到已有工作卡，进入编辑模式:', result.data);
        wx.hideLoading();
        
        wx.navigateTo({
          url: `/pages/work-card/work-card?edit=true&id=${result.data.id}`
        });
      } else {
        // 没有工作卡，进入新建模式
        console.log('ℹ️ 没有检测到工作卡，进入新建模式');
        wx.hideLoading();
        
        wx.navigateTo({
          url: '/pages/work-card/work-card'
        });
      }
    } catch (error) {
      console.error('检查工作卡失败:', error);
      wx.hideLoading();
      
      // 出错时默认进入新建模式
      wx.navigateTo({
        url: '/pages/work-card/work-card'
      });
    }
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
