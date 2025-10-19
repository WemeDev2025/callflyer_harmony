// test-wechat-login.js - 测试微信登录接口
console.log('🔐 测试微信登录接口...');

// 测试微信登录接口
const testWechatLogin = (code) => {
  console.log('📡 测试微信登录接口...');
  console.log('🔑 使用code:', code);
  
  wx.request({
    url: `https://wemedev.com/api/auth/wechat-login?code=${code}`,
    method: 'GET',
    header: {
      'Content-Type': 'application/json'
    },
    success: (res) => {
      console.log('✅ 微信登录接口成功:', res);
      if (res.data && res.data.user) {
        console.log('👤 用户信息:', res.data.user);
        console.log('🔑 Token:', res.data.token);
      }
    },
    fail: (err) => {
      console.log('❌ 微信登录接口失败:', err);
      console.log('🔍 错误详情:', {
        errMsg: err.errMsg,
        statusCode: err.statusCode,
        data: err.data
      });
    }
  });
};

// 测试不同的请求方式
const testDifferentMethods = (code) => {
  console.log('🧪 测试不同的请求方式...');
  
  // 1. GET请求（正确方式）
  console.log('1️⃣ 测试GET请求...');
  wx.request({
    url: `https://wemedev.com/api/auth/wechat-login?code=${code}`,
    method: 'GET',
    success: (res) => console.log('✅ GET请求成功:', res),
    fail: (err) => console.log('❌ GET请求失败:', err)
  });
  
  // 2. POST请求（错误方式）
  console.log('2️⃣ 测试POST请求...');
  wx.request({
    url: 'https://wemedev.com/api/auth/wechat-login',
    method: 'POST',
    data: { code: code },
    success: (res) => console.log('✅ POST请求成功:', res),
    fail: (err) => console.log('❌ POST请求失败:', err)
  });
};

// 执行测试
console.log('🚀 开始微信登录接口测试...');

// 使用测试code
const testCode = 'test_code_123456';
testWechatLogin(testCode);
testDifferentMethods(testCode);

module.exports = {
  testWechatLogin,
  testDifferentMethods,
  message: '微信登录接口测试完成'
};
