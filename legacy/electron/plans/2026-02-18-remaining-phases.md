# Stash 实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 完成 Phase 3（iCloud 同步 + 打磨），将 Stash 推进到完整产品。

**Architecture:** 在 Phase 1 + 2 已完成的基础上，添加 iCloud 同步层、加密存储、设置页、引导页、主题切换、性能优化和动画。

**Tech Stack:** Shiki（代码高亮）、framer-motion（动画）、react-window（虚拟滚动）、crypto（AES-256 加密）

---

## Phase 1 完成状态 ✅

| 模块 | 文件 | 状态 |
|------|------|------|
| 项目脚手架 | package.json, electron.vite.config.ts, tsconfig.* | ✅ |
| SQLite 数据库 | src/main/database/{connection,schema,repository}.ts | ✅ |
| 剪贴板监听 + 去重 | src/main/clipboard/{monitor,detector}.ts | ✅ |
| 快捷面板窗口 | src/main/window.ts, src/main/shortcuts.ts | ✅ |
| 基础列表 UI | src/renderer/src/components/Panel/*.tsx | ✅ |
| 搜索 + 键盘导航 | src/renderer/src/hooks/{useSearch,useKeyboard}.ts | ✅ |
| 粘贴机制 | src/main/index.ts (IPC pasteItem) | ✅ |
| 系统托盘 | src/main/tray.ts | ✅ |
| Zustand 状态管理 | src/renderer/src/stores/clipboardStore.ts | ✅ |

---

## Phase 2 完成状态 ✅

| Task | 模块 | 文件 | 状态 |
|------|------|------|------|
| T1 | Phase 2 依赖 | shiki, framer-motion, react-window, @types/react-window | ✅ |
| T2 | Shiki 代码高亮 | Preview/CodePreview.tsx | ✅ |
| T2 | 预览路由容器 | Preview/PreviewPanel.tsx（含 Text/Base64/URL 工具栏） | ✅ |
| T3 | JSON 格式化/校验 | Preview/JsonPreview.tsx | ✅ |
| T3 | 格式化工具函数 | utils/formatters.ts（formatJSON, decodeBase64, encodeBase64, encodeURL, decodeURL） | ✅ |
| T4 | 颜色预览 | Preview/ColorPreview.tsx（HEX/RGB/HSL 解析 + 色块 + 格式互转） | ✅ |
| T5 | 图片预览 | Preview/ImagePreview.tsx（base64 渲染 + 尺寸信息） | ✅ |
| T6 | 文本转换工具 | utils/transformers.ts（UPPER/lower/Title/camel/snake/kebab/trim） | ✅ |
| T7 | 类型筛选 Tab | Panel/FilterTabs.tsx（全部/收藏/文本/代码/URL/JSON/颜色/图片） | ✅ |
| T7 | 右键菜单 | Panel/ClipboardItem.tsx（粘贴/收藏/置顶/复制/删除） | ✅ |
| T8 | 分类管理 | repository.ts + IPC（categories CRUD + updateItemCategory） | ✅ |
| T9 | 快速编辑 | Panel/QuickEdit.tsx（双击编辑 → ⌘↵ 保存并粘贴） | ✅ |
| T10 | 模板片段 | Templates/TemplateList.tsx + TemplateEditor.tsx + IPC | ✅ |
| — | 面板布局升级 | PanelWindow.tsx（左右分栏 55%/45% + 剪贴板/模板 Tab 切换） | ✅ |

---

## Phase 3: iCloud 同步 + 打磨（1.5 周）

### Task 11: iCloud Drive 文件同步

**Files:**
- Create: `src/main/sync/icloud.ts`
- Modify: `src/main/index.ts` — 启动同步服务

**需求:**

**同步目录:** `~/Library/Mobile Documents/com~apple~CloudDocs/ZPaste/`

**同步策略：**
- 定时同步（每 5 分钟） + 数据变更触发
- 导出增量 JSON 变更日志（不是直接同步 SQLite 文件）
- 每条变更记录包含：操作类型（add/update/delete）、item 数据、时间戳

**冲突检测与合并：**
- 基于 `updated_at` 时间戳，最新写入优先
- 冲突时保留双方，标记为 `conflict`
- 首次同步：全量导出 + 按 `content_hash` 去重合并

**核心类结构:**
```typescript
export class iCloudSync {
  private syncDir: string
  private syncInterval: ReturnType<typeof setInterval> | null

  start(): void          // 启动定时同步
  stop(): void           // 停止同步
  exportChanges(): void  // 导出本地变更到 JSON 文件
  importChanges(): void  // 读取远端变更并合并
  fullSync(): void       // 首次全量同步
  resolveConflict(localItem, remoteItem): ClipboardItem
}
```

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: add iCloud Drive sync with conflict resolution"
```

---

### Task 12: 本地加密存储（AES-256）

**Files:**
- Create: `src/main/security/encryption.ts`
- Modify: `src/main/database/repository.ts` — 可选加密读写
- Modify: `src/main/sync/icloud.ts` — 同步数据加密

**需求:**
- 用户可在设置页开启加密
- 加密算法：AES-256-GCM
- 密钥由用户密码 + salt 通过 PBKDF2 派生
- 加密范围：clipboard_items.content 字段
- 同步文件也使用同一密钥加密

**核心函数:**
```typescript
export function deriveKey(password: string, salt: Buffer): Buffer
export function encrypt(plaintext: string, key: Buffer): { ciphertext: string; iv: string; tag: string }
export function decrypt(ciphertext: string, iv: string, tag: string, key: Buffer): string
```

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add AES-256-GCM encryption for local storage"
```

---

### Task 13: 暗色/亮色主题自适应

**Files:**
- Create: `src/renderer/src/stores/settingsStore.ts`
- Modify: `src/renderer/src/App.tsx` — 添加主题 provider
- Modify: `tailwind.config.js` — 确认 `darkMode: 'media'` 配置
- Modify: `src/renderer/src/assets/main.css` — 添加亮色主题变量
- Modify: `src/renderer/src/components/Panel/PanelWindow.tsx` — 使用主题 class

**需求:**
- 跟随 macOS 系统 `prefers-color-scheme` 自动切换
- 暗色：深灰背景 (#1e1e1e) + 白色文字
- 亮色：白色背景 + 深色文字
- Electron vibrancy 效果根据主题调整
- settingsStore 保存用户偏好（auto/dark/light）

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: add dark/light theme with system preference detection"
```

---

### Task 14: 设置页

**Files:**
- Create: `src/renderer/src/components/Settings/SettingsPage.tsx`
- Create: `src/renderer/src/components/Settings/SettingsItem.tsx`
- Modify: `src/renderer/src/App.tsx` — 添加设置页路由/切换
- Modify: `src/main/index.ts` — 添加设置相关 IPC

**需求:**

**设置项：**
- 通用：开机自启开关、历史保留时长（1天/7天/30天/永久）、最大记录数（500/1000/2000）
- 快捷键：自定义面板唤起快捷键
- 同步：iCloud 同步开关、立即同步按钮、同步状态显示
- 隐私：加密开关、一键清空所有数据
- 主题：自动/暗色/亮色
- 关于：版本号、GitHub 链接

**UI：**
- 全屏设置页（替换面板内容）
- 左侧导航 + 右侧设置项
- 通过面板底部齿轮图标或 Cmd+, 打开

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: add settings page"
```

---

### Task 15: 引导页（Onboarding）

**Files:**
- Create: `src/renderer/src/components/Onboarding/OnboardingPage.tsx`
- Modify: `src/renderer/src/stores/settingsStore.ts` — 添加 `hasCompletedOnboarding` 标志
- Modify: `src/renderer/src/App.tsx` — 首次启动显示引导页

**需求:**
- 3-4 步引导流程：
  1. 欢迎 + 功能介绍
  2. 核心快捷键 (Shift+Cmd+V) 动画演示
  3. 隐私说明 + iCloud 同步选择
  4. 完成 + 开始使用
- 底部进度点 + 下一步/跳过按钮
- 引导完成后设置 `hasCompletedOnboarding = true`，不再显示

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add onboarding flow"
```

---

### Task 16: electron-builder 打包 + DMG

**Files:**
- Modify: `electron-builder.yml` — 完善签名和公证配置
- Create: `build/entitlements.mac.plist`
- Create: `resources/icon.icns` — 应用图标
- Modify: `package.json` — 确认 build scripts

**需求:**
- 生成 DMG 安装包（arm64 + x64 universal）
- macOS entitlements：剪贴板访问、iCloud 容器
- 应用图标 1024x1024 icns
- LSUIElement = true（无 Dock 图标，仅托盘）

**entitlements.mac.plist:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
</dict>
</plist>
```

**Step 4: Commit**

```bash
git add -A && git commit -m "chore: configure electron-builder for DMG packaging"
```

---

### Task 17: 性能优化

**Files:**
- Modify: `src/renderer/src/components/Panel/ClipboardList.tsx` — 使用 react-window 虚拟滚动
- Modify: `src/renderer/src/components/Preview/ImagePreview.tsx` — 图片懒加载
- Modify: `src/main/clipboard/monitor.ts` — 大图片仅存路径
- Modify: `src/main/database/repository.ts` — 自动清理超限记录

**需求:**

**虚拟滚动（react-window）：**
```tsx
import { FixedSizeList } from 'react-window'

<FixedSizeList
  height={400}
  itemCount={items.length}
  itemSize={60}
  width="100%"
>
  {({ index, style }) => (
    <div style={style}>
      <ClipboardItemRow item={items[index]} index={index} isSelected={index === selectedIndex} />
    </div>
  )}
</FixedSizeList>
```

**图片懒加载：**
- 列表中图片仅显示占位符 + 尺寸信息
- 选中时才加载完整预览

**内存管控：**
- 超过 2000 条时自动删除最旧的非收藏/非置顶记录
- 超大图片（> 5MB）仅保存文件路径，不存 base64
- 目标：内存占用 < 120MB

**自动清理：**
```typescript
// repository.ts
export function autoCleanup(maxItems: number = 2000): void {
  const count = getItemCount()
  if (count > maxItems) {
    db.prepare(`
      DELETE FROM clipboard_items
      WHERE id IN (
        SELECT id FROM clipboard_items
        WHERE is_favorite = 0 AND is_pinned = 0
        ORDER BY updated_at ASC
        LIMIT ?
      )
    `).run(count - maxItems)
  }
}
```

**Step 5: Commit**

```bash
git add -A && git commit -m "perf: add virtual scrolling, lazy loading, and auto-cleanup"
```

---

### Task 18: 动画优化（framer-motion）

**Files:**
- Modify: `src/renderer/src/components/Panel/PanelWindow.tsx` — 面板出入动画
- Modify: `src/renderer/src/components/Panel/ClipboardItem.tsx` — 列表项动画

**需求:**
- 面板弹出/收起动画：spring 配置，总时长 < 150ms
- 列表项新增时 slide-in 动画
- 删除时 fade-out 动画
- 使用 `framer-motion` 的 `AnimatePresence` + `motion.div`

```tsx
import { motion, AnimatePresence } from 'framer-motion'

// 面板动画
<motion.div
  initial={{ opacity: 0, scale: 0.95, y: 10 }}
  animate={{ opacity: 1, scale: 1, y: 0 }}
  exit={{ opacity: 0, scale: 0.95, y: 10 }}
  transition={{ type: 'spring', stiffness: 500, damping: 30 }}
>
```

**Step 3: Commit**

```bash
git add -A && git commit -m "feat: add framer-motion animations (< 150ms)"
```

---

## Phase 3 待创建文件清单

| 文件路径 | 所属 Task | 状态 |
|----------|----------|------|
| `src/main/sync/icloud.ts` | Task 11 | ✅ |
| `src/main/security/encryption.ts` | Task 12 | ✅ |
| `src/renderer/src/stores/settingsStore.ts` | Task 13 | ✅ |
| `src/renderer/src/components/Settings/SettingsPage.tsx` | Task 14 | ✅ |
| `src/renderer/src/components/Settings/SettingsItem.tsx` | Task 14 | ✅ |
| `src/renderer/src/components/Onboarding/OnboardingPage.tsx` | Task 15 | ✅ |
| `build/entitlements.mac.plist` | Task 16 | ✅ |
| `resources/icon.icns` | Task 16 | ✅ |

---

## Phase 3 执行顺序建议

```
Phase 3（按依赖关系排列）:
  Task 13 → 主题（前置，settingsStore 被后续依赖）
  Task 14 → 设置页（依赖 settingsStore）
  Task 15 → 引导页（依赖 settingsStore）
  ↑ Task 13-15 顺序执行 ↑
  Task 11 → iCloud 同步（独立，需要设置页联动）
  Task 12 → 加密存储（独立，需要设置页联动）
  Task 16 → 打包配置（独立）
  Task 17 → 性能优化（独立）
  Task 18 → 动画优化（独立）
  ↑ Task 11/12/16/17/18 可并行开发 ↑
```

---

## 验证命令

每个 Task 完成后运行：
```bash
# 类型检查
npm run typecheck

# 构建验证
npx electron-vite build

# 运行验证
npm run dev
```

最终交付验证：
```bash
# 打包 DMG
npm run build:mac
```
