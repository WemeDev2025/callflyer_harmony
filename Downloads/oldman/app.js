// app.js
const dataManager = require('./utils/dataManager');

App({
  onLaunch() {
    // 应用启动时的初始化
    this.initApp();
  },

  // 初始化应用
  async initApp() {
    try {
      // 检查是否已有用户信息
      const existingUserInfo = wx.getStorageSync('userInfo');
      const existingToken = wx.getStorageSync('userToken');
      
      if (existingUserInfo && existingToken) {
        // 验证token有效性
        console.log('验证现有token有效性...');
        const userResult = await dataManager.user.getInfo();
        if (userResult.success) {
          this.globalData.userInfo = userResult.data;
          console.log('用户已登录:', userResult.data);
          return;
        } else {
          console.log('token验证失败:', userResult.message);
          // token无效，清除本地存储
          wx.removeStorageSync('userToken');
          wx.removeStorageSync('userInfo');
        }
      }
      
      // 执行静默登录
      await this.silentLogin();
    } catch (error) {
      console.error('应用初始化失败:', error);
      // 初始化失败时，尝试静默登录
      await this.silentLogin();
    }
  },

  // 微信静默登录
  async silentLogin() {
    try {
      console.log('开始静默登录...');
      
      // 获取微信登录凭证
      const loginRes = await new Promise((resolve, reject) => {
        wx.login({
          success: resolve,
          fail: reject
        });
      });

      if (!loginRes.code) {
        console.error('获取微信登录凭证失败');
        return;
      }

      console.log('获取到微信code:', loginRes.code);

      // 调用后端登录接口
      console.log('🔐 开始调用后端登录接口...');
      const result = await dataManager.user.login({
        code: loginRes.code,
        type: 'wechat'
      });

      console.log('📊 登录接口返回结果:', result);

      if (result.success) {
        this.globalData.userInfo = result.data;
        console.log('✅ 静默登录成功:', result.data);
        
        // 保存用户信息到本地
        wx.setStorageSync('userInfo', result.data);
        wx.setStorageSync('userToken', result.data.token);
        
        console.log('💾 用户数据已保存到本地存储');
      } else {
        console.error('❌ 静默登录失败:', result.message);
        console.log('📋 失败详情:', {
          success: result.success,
          message: result.message,
          data: result.data
        });
        // 静默登录失败不影响应用使用，用户仍可正常使用功能
        console.log('ℹ️ 静默登录失败，用户可正常使用应用功能');
      }
    } catch (error) {
      console.error('静默登录异常:', error);
      // 静默登录失败不影响应用使用
    }
  },

  // 模拟登录（用于开发测试）
  async mockLogin(code) {
    try {
      console.log('使用模拟登录...');
      
      // 创建模拟用户数据
      const mockUserInfo = {
        id: 'mock_' + Date.now(),
        openid: 'mock_openid_' + code,
        nickname: '微信用户',
        avatar: '',
        phone: '',
        gender: 0,
        city: '',
        province: '',
        country: '中国',
        createdAt: new Date().toISOString()
      };

      const mockToken = 'mock_token_' + Date.now();

      // 保存模拟数据
      this.globalData.userInfo = mockUserInfo;
      wx.setStorageSync('userInfo', mockUserInfo);
      wx.setStorageSync('userToken', mockToken);
      
      console.log('模拟登录成功:', mockUserInfo);
    } catch (error) {
      console.error('模拟登录失败:', error);
    }
  },

  // 手动刷新用户信息
  async refreshUserInfo() {
    try {
      const result = await dataManager.user.getInfo();
      if (result.success) {
        this.globalData.userInfo = result.data;
        wx.setStorageSync('userInfo', result.data);
        return { success: true };
      } else {
        return { success: false, message: result.message };
      }
    } catch (error) {
      console.error('刷新用户信息失败:', error);
      return { success: false, message: '刷新失败' };
    }
  },

  // 用户登出
  logout() {
    this.globalData.userInfo = null;
    wx.removeStorageSync('userToken');
    wx.removeStorageSync('userInfo');
    // 清除数据缓存
    dataManager.clearCache();
    console.log('用户已登出');
  },

  // 检查登录状态
  isLoggedIn() {
    return !!this.globalData.userInfo;
  },

  // 获取用户信息
  getUserInfo() {
    return this.globalData.userInfo;
  },

  globalData: {
    userInfo: null,
    apiBaseUrl: 'https://wemedev.com/api'
  }
})
