# 春节倒计时 小程序（示例）

项目位置：`/Users/zhaojing/Downloads/Festival`

功能：启动后显示一个带实时秒级更新的“春节倒计时”卡片，目标日期为 2026-02-17（丙午年正月初一）。

快速运行：
```bash
# 在 macOS 上：
# 1. 打开微信开发者工具
# 2. 选择 “导入项目”，路径选择本文件夹，AppID 可为空
# 3. 运行/预览即可看到 `pages/index/index` 页面
```

文件说明：
- `app.json`：小程序页面配置
- `app.js` / `app.wxss`：全局脚本与样式
- `pages/index/*`：倒计时页面的视图、样式和逻辑

如果你希望更炫的视觉效果（粒子、雪花、SVG 动画、SVG 文案），我可以继续增强样式或接入 Canvas 动画。

关于 JS 压缩与组件按需注入
- 压缩：仓库已添加 `package.json` 和 `scripts/minify.js`（使用 `terser`）。运行 `npm install` 后执行：

```bash
npm install
npm run minify
```

	该命令会把压缩后的 JS 和其他资源复制到 `dist/` 目录，方便将 `dist` 导入微信开发者工具进行校验或发包。

- 组件按需注入：粒子效果已拆成 `components/spark` 组件，页面通过 `wx:if="{{showSparks}}"` 延迟显示实现按需加载（组件只在显示时渲染），并在 `pages/index/index.json` 中按需注册。

