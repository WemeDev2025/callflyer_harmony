// test-api-response.js - 测试API响应格式
console.log('🧪 测试API响应格式处理...');

const ResponseAdapter = require('./utils/dataAdapter').ResponseAdapter;

// 测试不同的响应格式
const testCases = [
  {
    name: '嵌套格式（当前后端返回）',
    response: {
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
    }
  },
  {
    name: '直接格式（旧格式）',
    response: {
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
  },
  {
    name: '标准格式',
    response: {
      "code": 0,
      "success": true,
      "data": {
        "user": {
          "id": "68f3236fe42e232a0e447292",
          "nickname": "微信用户"
        },
        "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
      },
      "message": "登录成功"
    }
  }
];

// 测试所有格式
testCases.forEach((testCase, index) => {
  console.log(`\n📋 测试用例 ${index + 1}: ${testCase.name}`);
  console.log('📥 输入响应:', testCase.response);
  
  const result = ResponseAdapter.handleResponse(testCase.response);
  
  console.log('🔄 处理结果:', result);
  
  if (result.success) {
    console.log('✅ 处理成功!');
    console.log('👤 用户信息:', result.data.user);
    console.log('🔑 Token:', result.data.token);
  } else {
    console.log('❌ 处理失败:', result.message);
  }
});

console.log('\n🎯 测试完成！所有响应格式都应该被正确处理。');

module.exports = {
  testCases,
  message: 'API响应格式测试完成'
};
