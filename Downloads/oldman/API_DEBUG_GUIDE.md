# API调试指南

## 🚨 当前问题

### 问题1: 用户信息接口失败
```
API请求错误: 请求失败 null
获取用户信息失败: Error: 请求失败
```

### 问题2: 应用使用模拟数据
```
用户已登录: {id: "mock_1760764882032", ...}
```

## 🔍 问题分析

### 1. 网络请求失败
- **现象**: `请求失败 null`
- **可能原因**: 
  - 网络连接问题
  - API服务器不可访问
  - 接口路径错误
  - 认证头问题

### 2. 模拟数据被启用
- **现象**: 显示mock用户数据
- **原因**: API请求失败后，应用回退到模拟登录

## 🛠️ 调试步骤

### 步骤1: 检查网络连接
```javascript
// 在控制台执行
wx.request({
  url: 'https://wemedev.com/',
  method: 'GET',
  success: (res) => console.log('✅ 服务器可访问:', res),
  fail: (err) => console.log('❌ 服务器不可访问:', err)
});
```

### 步骤2: 检查API文档
```javascript
// 检查API文档是否可访问
wx.request({
  url: 'https://wemedev.com/docs',
  method: 'GET',
  success: (res) => console.log('✅ API文档可访问:', res),
  fail: (err) => console.log('❌ API文档不可访问:', err)
});
```

### 步骤3: 测试用户信息接口
```javascript
// 测试用户信息接口
wx.request({
  url: 'https://wemedev.com/user/info',
  method: 'GET',
  header: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer YOUR_TOKEN'
  },
  success: (res) => console.log('✅ 用户信息接口:', res),
  fail: (err) => console.log('❌ 用户信息接口失败:', err)
});
```

### 步骤4: 测试微信登录接口
```javascript
// 测试微信登录接口
wx.request({
  url: 'https://wemedev.com/api/auth/wechat-login',
  method: 'POST',
  data: { code: 'test_code' },
  header: { 'Content-Type': 'application/json' },
  success: (res) => console.log('✅ 微信登录接口:', res),
  fail: (err) => console.log('❌ 微信登录接口失败:', err)
});
```

## 🔧 修复方案

### 方案1: 检查API服务器状态
1. 访问 https://wemedev.com/docs
2. 确认API文档是否可访问
3. 检查服务器是否正常运行

### 方案2: 检查接口路径
根据API文档确认正确的接口路径：
- 用户信息: `/user/info` ✅
- 微信登录: `/api/auth/wechat-login` ✅

### 方案3: 检查认证
确保请求包含正确的认证头：
```javascript
header: {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer ' + token
}
```

### 方案4: 网络配置
1. 检查微信开发者工具网络设置
2. 确认域名白名单配置
3. 检查代理设置

## 📋 调试命令

### 快速测试脚本
```javascript
// 在控制台执行以下代码进行快速测试
const debugAPI = require('./debug-api.js');
debugAPI.testAPI();
debugAPI.testWechatLogin();
```

### 手动测试
```javascript
// 1. 测试基础连接
wx.request({
  url: 'https://wemedev.com/',
  success: console.log,
  fail: console.error
});

// 2. 测试API文档
wx.request({
  url: 'https://wemedev.com/docs',
  success: console.log,
  fail: console.error
});

// 3. 测试用户信息接口
wx.request({
  url: 'https://wemedev.com/user/info',
  method: 'GET',
  header: { 'Content-Type': 'application/json' },
  success: console.log,
  fail: console.error
});
```

## 🎯 预期结果

### 成功情况
```
✅ 服务器可访问
✅ API文档可访问  
✅ 用户信息接口返回用户数据
✅ 微信登录接口正常工作
```

### 失败情况
```
❌ 网络连接失败
❌ 服务器不可访问
❌ 接口返回错误
❌ 认证失败
```

## 📞 联系支持

如果问题持续存在，请提供：
1. 完整的错误日志
2. 网络请求详情
3. API服务器状态
4. 微信开发者工具版本
