# 序列粘贴功能设计

## 概述

为 Stash 增加序列粘贴功能，支持两种模式：

- **队列粘贴**：用户将多条剪贴板记录加入队列，通过快捷键逐条粘贴
- **批量粘贴**：用户多选记录后，一次性全部粘贴到光标处

## 快捷键

所有快捷键支持在设置中自定义：

| 功能 | 默认快捷键 |
|------|-----------|
| 序列粘贴（下一条） | Cmd+; |
| 批量粘贴 | Cmd+' |
| 面板内添加到队列 | Space |
| 面板内多选 | Cmd+Click / Shift+Click |

## 数据模型与状态管理

在 `clipboardStore` 中新增：

```ts
sequenceQueue: ClipboardItem[]  // 有序队列数组
queueIndex: number              // 当前粘贴位置（初始 0）
isQueueActive: boolean          // 队列模式是否激活
```

操作方法：

- `addToQueue(item)` — 追加单条到队列末尾
- `addMultipleToQueue(items)` — 批量追加（保持选择顺序）
- `pasteNext()` — 粘贴当前 index 项并 index++，末尾后自动清空队列
- `pasteBatch(items)` — 一次性粘贴所有选中项（用分隔符拼接），不影响队列
- `removeFromQueue(index)` — 移除指定项
- `clearQueue()` — 清空队列

## 快捷键与主进程交互

### 快捷键注册（shortcuts.ts）

- `Cmd+;`：全局快捷键，从队列取当前项，模拟粘贴写入光标位置，index 前进
- `Cmd+'`：全局快捷键，将所有选中项用分隔符拼接，写入剪贴板后模拟 Cmd+V

### 面板内交互（Panel 组件）

- `Space` 键：将当前高亮条目加入队列，气泡提示"已加入队列 (N)"
- `Cmd+Click` / `Shift+Click`：多选条目，按 Enter 批量加入队列
- 已加入队列的条目显示序号角标，视觉区分

### IPC 通信

- renderer → main：`queue:add`、`queue:clear`
- main → renderer：`queue:status-update`（同步队列状态到 Tray 角标）

## UI 反馈

### 气泡提示

复用现有 toast/notification 组件：

- 添加时：「已加入队列 (3)」
- 粘贴时：「已粘贴 2/5」
- 队列清空：「队列已清空」
- 批量粘贴：「已批量粘贴 4 条」

### Tray 角标

- 队列激活时，Tray 图标右上角显示剩余数量数字角标
- 队列清空后角标消失，恢复普通图标

### 设置页面

在 Settings 中新增序列粘贴配置区：

- 序列粘贴快捷键（默认 Cmd+;）
- 批量粘贴快捷键（默认 Cmd+'）
- 添加到队列快捷键（默认 Space）
- 批量粘贴分隔符（默认换行，可选 Tab / 自定义）

## 队列行为

- 最后一条粘贴完后，自动退出队列模式
- Cmd+; 恢复无效果，气泡提示"队列已清空"
- 不提供循环模式，保持简单
