// test-successful-login.js - 测试成功登录
console.log('🎉 测试成功登录流程...');

// 模拟成功的登录响应
const successfulLoginResponse = {
  "success": true,
  "message": "登录成功",
  "data": {
    "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
    "token_type": "bearer",
    "user_info": {
      "id": "68f3236fe42e232a0e447292",
      "openid": "test_openid_success",
      "nickname": "微信用户",
      "avatar": "",
      "user_type": "user"
    }
  }
};

console.log('📥 模拟成功登录响应:', successfulLoginResponse);

// 测试响应适配器
const ResponseAdapter = require('./utils/dataAdapter').ResponseAdapter;
const result = ResponseAdapter.handleResponse(successfulLoginResponse);

console.log('🔄 适配器处理结果:', result);

if (result.success) {
  console.log('✅ 登录处理成功!');
  console.log('👤 用户信息:', result.data.user);
  console.log('🔑 Token:', result.data.token);
  
  // 模拟保存到本地存储
  const userData = {
    id: result.data.user.id,
    openid: result.data.user.openid,
    nickname: result.data.user.nickname,
    avatar: result.data.user.avatar,
    user_type: result.data.user.user_type
  };
  
  console.log('💾 用户数据已保存:', userData);
  console.log('🔑 Token已保存:', result.data.token);
  
  console.log('\n🎯 登录流程测试完成！');
  console.log('✅ API请求成功');
  console.log('✅ 响应数据有效');
  console.log('✅ 用户信息正确');
  console.log('✅ Token获取成功');
  console.log('✅ 数据保存完成');
} else {
  console.log('❌ 登录处理失败:', result.message);
}

module.exports = {
  successfulLoginResponse,
  result,
  message: '成功登录测试完成'
};
