# CallFlyer Harmony 项目开发规范

## 功能开发流程

新增功能开发时，按照以下步骤逐步推进，每步标记状态直到完成：

### 流程步骤

```
[ ] 需求分析
    - 理解后端接口返回格式
    - 确定前端数据模型

[ ] 接口接入（ApiService.ets）
    - 定义 TypeScript 接口（如有）
    - 实现请求函数
    - 标记：接口完成

[ ] 页面状态管理
    - 定义 @State 状态变量
    - 定义私有变量
    - 标记：状态完成

[ ] 数据绑定
    - aboutToAppear 中调用接口
    - 接口返回数据赋值给状态
    - 标记：绑定完成

[ ] UI 渲染
    - 实现或修改 build() 中的组件
    - 使用 $r() 引用颜色资源（深浅色适配）
    - 标记：UI 完成

[ ] 功能测试
    - 热更新验证
    - 检查日志输出
    - 标记：测试完成

[ ] Git 提交推送
    - git add
    - git commit -m "类型: 简短描述"
    - git push
    - 标记：推送完成
```

### 提交信息格式

```
<类型>: <简短描述>

类型：
- feat: 新功能
- fix: 修复bug
- refactor: 重构
- docs: 文档
- style: 格式调整
- test: 测试
- chore: 构建/工具
```

### ArkTS 规范

- 禁止使用索引访问对象属性（使用 if-else 链替代）
- 使用 `HitTestMode` 处理 Stack 层级点击事件
- 使用 `$r('app.color.*')` 引用颜色资源实现深浅色适配
- `@State` 变量才能触发 UI 更新
- CustomDialog 的 controller 需在组件外部初始化

### 深浅色适配

- 颜色定义在 `entry/src/main/resources/base/element/color.json`
- 深色颜色定义在 `entry/src/main/resources/dark/element/color.json`
- 使用 `@StorageLink('colorMode')` 监听系统颜色模式
- 使用 `$r('app.color.*')` 引用颜色而非硬编码

### 标签功能开发记录

#### feat: 使用新接口 /api/profiles/certified/tags 动态获取标签列表

- [x] 需求分析 - 后端返回 `{tags: [{key, label, count}]}` 格式
- [x] 接口接入 - ApiService.ets 新增 `fetchCertifiedTags()` 和 `CertifiedTag` 接口
- [x] 页面状态管理 - roleOptions 初始化为空数组
- [x] 数据绑定 - aboutToAppear 调用 loadTags() 获取标签列表
- [x] UI 渲染 - 标签行使用 ForEach 渲染 roleOptions
- [x] 功能测试 - 验证标签显示和切换
- [x] Git 提交推送
