// test-response-adapter.js - 测试响应适配器
console.log('🧪 测试响应适配器...');

const ResponseAdapter = require('./utils/dataAdapter').ResponseAdapter;

// 模拟后端返回的微信登录响应（嵌套格式）
const mockWechatLoginResponse = {
  "success": true,
  "message": "登录成功",
  "data": {
    "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
    "token_type": "bearer",
    "user_info": {
      "id": "68f3236fe42e232a0e447292",
      "openid": "test_openid_test123",
      "nickname": "微信用户",
      "avatar": "",
      "user_type": "user"
    }
  }
};

// 测试响应适配器
console.log('📥 模拟后端响应:', mockWechatLoginResponse);

const result = ResponseAdapter.handleResponse(mockWechatLoginResponse);

console.log('🔄 适配器处理结果:', result);

// 验证结果
if (result.success) {
  console.log('✅ 适配器处理成功!');
  console.log('👤 用户信息:', result.data.user);
  console.log('🔑 Token:', result.data.token);
} else {
  console.log('❌ 适配器处理失败:', result.message);
}

module.exports = {
  mockWechatLoginResponse,
  result,
  message: '响应适配器测试完成'
};
