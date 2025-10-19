// debug-api.js - API调试脚本
console.log('🔍 开始API调试...');

// 测试API连接
const testAPI = () => {
  console.log('📡 测试API连接...');
  
  // 测试基础连接
  wx.request({
    url: 'https://wemedev.com/user/info',
    method: 'GET',
    header: {
      'Content-Type': 'application/json'
    },
    success: (res) => {
      console.log('✅ API连接成功:', res);
    },
    fail: (err) => {
      console.log('❌ API连接失败:', err);
      
      // 测试不同的路径
      console.log('🔧 尝试其他路径...');
      
      // 测试根路径
      wx.request({
        url: 'https://wemedev.com/',
        method: 'GET',
        success: (res) => {
          console.log('✅ 根路径可访问:', res);
        },
        fail: (err) => {
          console.log('❌ 根路径不可访问:', err);
        }
      });
      
      // 测试API文档路径
      wx.request({
        url: 'https://wemedev.com/docs',
        method: 'GET',
        success: (res) => {
          console.log('✅ API文档可访问:', res);
        },
        fail: (err) => {
          console.log('❌ API文档不可访问:', err);
        }
      });
    }
  });
};

// 测试微信登录接口
const testWechatLogin = () => {
  console.log('🔐 测试微信登录接口...');
  
  wx.request({
    url: 'https://wemedev.com/api/auth/wechat-login',
    method: 'POST',
    data: {
      code: 'test_code_123456'
    },
    header: {
      'Content-Type': 'application/json'
    },
    success: (res) => {
      console.log('✅ 微信登录接口响应:', res);
    },
    fail: (err) => {
      console.log('❌ 微信登录接口失败:', err);
    }
  });
};

// 执行测试
console.log('🚀 开始API调试测试...');
testAPI();
testWechatLogin();

module.exports = {
  testAPI,
  testWechatLogin,
  message: 'API调试脚本已执行'
};
