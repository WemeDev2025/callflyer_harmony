// debug-api-connection.js - API连接调试工具
console.log('🔍 开始API连接调试...');

// 测试微信登录接口的详细调试
const debugWechatLogin = (code) => {
  console.log('🔐 调试微信登录接口...');
  console.log('📋 测试参数:', {
    code: code,
    url: `https://wemedev.com/api/auth/wechat-login?code=${code}`,
    method: 'GET'
  });

  wx.request({
    url: `https://wemedev.com/api/auth/wechat-login?code=${code}`,
    method: 'GET',
    header: {
      'Content-Type': 'application/json'
    },
    success: (res) => {
      console.log('✅ 微信登录接口成功响应:');
      console.log('📊 响应详情:', {
        statusCode: res.statusCode,
        data: res.data,
        header: res.header
      });
      
      if (res.data && res.data.user) {
        console.log('👤 用户信息:', res.data.user);
        console.log('🔑 Token:', res.data.token);
      }
    },
    fail: (err) => {
      console.log('❌ 微信登录接口失败:');
      console.log('🔍 错误详情:', {
        errMsg: err.errMsg,
        statusCode: err.statusCode,
        data: err.data,
        header: err.header
      });
    }
  });
};

// 测试用户信息接口
const debugUserInfo = () => {
  console.log('👤 调试用户信息接口...');
  
  wx.request({
    url: 'https://wemedev.com/user/info',
    method: 'GET',
    header: {
      'Content-Type': 'application/json'
    },
    success: (res) => {
      console.log('✅ 用户信息接口成功响应:');
      console.log('📊 响应详情:', {
        statusCode: res.statusCode,
        data: res.data,
        header: res.header
      });
    },
    fail: (err) => {
      console.log('❌ 用户信息接口失败:');
      console.log('🔍 错误详情:', {
        errMsg: err.errMsg,
        statusCode: err.statusCode,
        data: err.data
      });
    }
  });
};

// 测试网络连接
const debugNetworkConnection = () => {
  console.log('🌐 调试网络连接...');
  
  // 测试基础连接
  wx.request({
    url: 'https://wemedev.com/',
    method: 'GET',
    success: (res) => {
      console.log('✅ 基础连接成功:', res.statusCode);
    },
    fail: (err) => {
      console.log('❌ 基础连接失败:', err);
    }
  });
  
  // 测试API文档
  wx.request({
    url: 'https://wemedev.com/docs',
    method: 'GET',
    success: (res) => {
      console.log('✅ API文档可访问:', res.statusCode);
    },
    fail: (err) => {
      console.log('❌ API文档不可访问:', err);
    }
  });
};

// 执行所有调试测试
const runAllDebugTests = () => {
  console.log('🚀 开始执行所有调试测试...');
  
  // 1. 测试网络连接
  debugNetworkConnection();
  
  // 2. 测试用户信息接口
  debugUserInfo();
  
  // 3. 测试微信登录接口
  const testCode = 'debug_test_code_123456';
  debugWechatLogin(testCode);
  
  console.log('📋 调试测试完成，请查看控制台输出');
};

// 导出调试函数
module.exports = {
  debugWechatLogin,
  debugUserInfo,
  debugNetworkConnection,
  runAllDebugTests
};

// 自动执行调试测试
runAllDebugTests();
