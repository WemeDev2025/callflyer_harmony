# 远程配置使用说明

## 概述

远程配置系统用于从服务器动态控制功能的显示/隐藏，目前支持控制首页"拜年卡片"按钮的显示状态。

## 配置文件位置

- **配置工具**: `utils/config.js`
- **使用页面**: `pages/index/index.js`

## API 接口

配置系统会从以下接口获取配置：

```
GET https://wemedev.com/api/festival/config
```

### 请求示例

```bash
curl -X GET https://wemedev.com/api/festival/config
```

### 响应格式

```json
{
  "showNewYearButton": true
}
```

**字段说明**:
- `showNewYearButton`: `boolean` - 是否显示"拜年卡片"按钮
  - `true`: 显示按钮（默认值）
  - `false`: 隐藏按钮

## 服务器端实现

你需要在后端实现 `/api/festival/config` 接口，返回配置信息。

### 示例响应

```json
{
  "showNewYearButton": false
}
```

返回此配置后，首页的"拜年卡片"按钮将被隐藏。

## 功能特性

1. **缓存机制**: 配置会缓存 5 分钟，减少请求频率
2. **容错处理**: 如果请求失败，会使用默认配置（显示按钮），不影响应用正常运行
3. **默认值**: 如果服务器未返回配置或字段缺失，默认显示按钮

## 清除缓存

如果需要立即获取最新配置，可以调用：

```javascript
const config = require('../../utils/config');
config.clearConfigCache();
```

## 扩展配置

如需添加更多配置项，可以：

1. 在 `utils/config.js` 的 `getDefaultConfig()` 中添加默认值
2. 在服务器响应中添加新字段
3. 在页面中使用配置值控制功能

示例：

```javascript
// utils/config.js
function getDefaultConfig() {
  return {
    showNewYearButton: true,
    showNewFeature: false, // 新增配置项
  };
}

// pages/index/index.js
this.setData({
  showNewYearButton: remoteConfig.showNewYearButton !== false,
  showNewFeature: remoteConfig.showNewFeature === true, // 使用新配置
});
```




