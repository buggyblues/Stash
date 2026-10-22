# Mac 小组件设计文档

## 概述

为 Stash 增加两种小组件形态，展示最近 5 条剪贴板内容，支持可配置快捷键直接粘贴。

## 功能一：桌面悬浮小窗口 (Widget Window)

### 窗口属性
- 尺寸：280×320px，圆角、无边框
- `vibrancy: 'under-window'` 毛玻璃半透明效果
- `alwaysOnTop: true`，失焦不自动隐藏
- 可拖动（顶部标题栏区域）
- 记住上次位置（存 localStorage）

### UI 结构
```
┌─────────────────────────┐
│ 📋 最近剪贴板    📌 ✕  │  ← 标题栏 + 钉住按钮
├─────────────────────────┤
│ ⌥1  今天开会的内容...   │  ← 快捷键标记 + 文本摘要
│ ⌥2  https://github...   │
│ ⌥3  const foo = ...     │
│ ⌥4  #FF5722             │
│ ⌥5  SELECT * FROM...    │
├─────────────────────────┤
│ ⚙️ 快捷键: ⌥+数字      │  ← 底部提示
└─────────────────────────┘
```

### 交互
- 点击某项 → 直接粘贴到上一个活跃应用
- 📌 钉住 → 常驻桌面；取消钉住 → 通过快捷键呼出/隐藏
- 实时更新：新剪贴板内容自动刷新列表

## 功能二：菜单栏下拉面板 (Tray Popup)

- 扩展现有 `TrayManager`，在原有菜单项上方插入最近 5 条
- 每项显示：`⌥1  文本摘要（截断40字符）`
- 点击某项 → 写入剪贴板并模拟 Cmd+V 粘贴
- 底部保留原有菜单（打开面板、开机自启、退出）

## 快捷键配置

### 全局快捷键
- `Option+1` ~ `Option+5`：快捷粘贴对应项（前缀键可配置）
- `Option+W`：切换悬浮小组件显隐（可配置）

### Settings 新增项
- **小组件快捷粘贴前缀**：默认 `Alt`(Option)，可改为 `Ctrl` 等
- **切换悬浮小组件**：默认 `Alt+W`，快捷键录入器配置

## 数据源设置

### widgetFollowFilter
- 在 Settings → General 中新增：**小组件数据源**
- **独立模式（默认）**：`widgetFollowFilter: false`，展示最新 5 条，不受任何筛选影响
- **跟随主面板**：`widgetFollowFilter: true`，与主面板 filterType/leftFilter/sourceAppFilter 同步

## 数据流

- 主进程维护 `recentItems`（最近5条），由 `ClipboardMonitor` 新内容时更新
- Widget 窗口通过 IPC 获取数据，监听 `clipboard:newItem` 实时刷新
- Tray 菜单在每次弹出时重新读取最新 5 条构建
- 跟随模式下，主面板筛选变更通过 IPC 通知主进程，主进程同步更新 widget 数据

## 技术实现要点

### 新增文件
- `src/main/widget.ts` — WidgetWindowManager，管理悬浮窗生命周期
- `src/renderer/widget.html` — Widget 独立入口 HTML
- `src/renderer/src/Widget.tsx` — Widget React 根组件
- `src/renderer/src/components/Widget/WidgetPanel.tsx` — Widget UI

### 修改文件
- `src/main/index.ts` — 初始化 widget，注册 IPC
- `src/main/shortcuts.ts` — 注册 Option+1~5、Option+W
- `src/main/tray.ts` — 插入最近 5 条菜单项
- `src/preload/index.ts` — 新增 widget 相关 IPC API
- `src/renderer/src/stores/settingsStore.ts` — 新增 widget 设置字段
- `src/renderer/src/components/Settings/SettingsPage.tsx` — 新增配置 UI
- `electron.vite.config.ts` — 新增 widget renderer 入口
- 国际化文件 — 新增翻译 key
