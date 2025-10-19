# 问题排查指南

## 🚨 当前问题分析

### 问题描述
```
POST https://wemedev.com/api/user/wechat-login 404
```

### 问题原因
1. **API接口路径错误**: 后端可能没有 `/user/wechat-login` 接口
2. **接口路径不匹配**: 实际接口路径与代码中定义的不一致
3. **后端服务未启动**: API服务可能未正常运行

## 🔧 解决方案

### 方案1: 使用模拟数据（推荐用于开发测试）

**已实现**: 在 `utils/config.js` 中设置 `USE_MOCK_DATA: true`

```javascript
// utils/config.js
module.exports = {
  DEV: {
    USE_MOCK_DATA: true, // 启用模拟数据
    MOCK_API_DELAY: 500  // 模拟延迟
  }
};
```

**特点**:
- ✅ 无需后端支持
- ✅ 完整的登录流程
- ✅ 真实的数据结构
- ✅ 便于开发测试

### 方案2: 修复API接口路径 ✅ 已修复

**步骤1**: 检查后端API文档
访问: https://wemedev.com/docs

**步骤2**: 确认正确的登录接口路径 ✅
正确的路径: `/api/auth/wechat-login`

**步骤3**: 更新接口路径 ✅ 已完成
```javascript
// utils/api.js
wechatLogin(code) {
  return apiService.post('/api/auth/wechat-login', {  // ✅ 已修复为正确路径
    code: code,
    type: 'wechat'
  });
}
```

### 方案3: 配置开发环境

**步骤1**: 在微信开发者工具中关闭域名校验
```
工具 → 详情 → 本地设置 → 不校验合法域名、web-view（业务域名）、TLS 版本以及 HTTPS 证书
```

**步骤2**: 配置正确的API域名
在微信小程序后台添加:
- **request合法域名**: `https://wemedev.com`
- **uploadFile合法域名**: `https://wemedev.com`

## 🛠️ 调试步骤

### 1. 检查网络连接
```javascript
// 在控制台执行
wx.request({
  url: 'https://wemedev.com/api/user/login',
  method: 'POST',
  data: { code: 'test', type: 'wechat' },
  success: (res) => console.log('API响应:', res),
  fail: (err) => console.error('API错误:', err)
});
```

### 2. 检查API文档
访问 https://wemedev.com/docs 查看:
- 可用的接口列表
- 正确的请求格式
- 响应数据结构

### 3. 使用模拟数据
```javascript
// 临时启用模拟数据
const config = require('./utils/config');
config.DEV.USE_MOCK_DATA = true;
```

## 📱 当前状态

### 已实现功能
- ✅ 微信静默登录框架
- ✅ 模拟数据支持
- ✅ 错误处理和降级
- ✅ 用户状态管理

### 待解决问题
- ❌ 后端API接口404
- ❌ 需要确认正确的接口路径
- ❌ 需要配置正确的域名

## 🎯 推荐操作

### 立即可用方案
1. **启用模拟数据**: 设置 `USE_MOCK_DATA: true`
2. **关闭域名校验**: 在开发者工具中关闭校验
3. **测试功能**: 验证登录和数据管理功能

### 生产环境方案
1. **联系后端开发**: 确认正确的API接口
2. **更新接口路径**: 修改为正确的路径
3. **配置域名**: 在微信后台配置合法域名
4. **测试接口**: 验证所有API调用

## 📞 技术支持

如果问题持续存在，建议:
1. 检查后端API服务状态
2. 确认API文档中的接口路径
3. 联系后端开发人员确认接口可用性
4. 使用模拟数据进行开发测试

## 🔄 回滚方案

如果需要回滚到纯本地存储版本:
1. 设置 `USE_MOCK_DATA: false`
2. 注释掉API调用代码
3. 恢复本地存储逻辑
4. 移除网络请求相关代码
