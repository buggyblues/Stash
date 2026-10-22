# Stash 2.0.0 — 原生 macOS 版本

Stash 剪贴板管理器的 **Swift / SwiftUI 重写版**。这是唯一受支持的应用实现；Electron 1.x 已废弃，历史代码位于 `legacy/electron/`。
数据库、加密载荷和 iCloud 文件格式已有兼容性测试；真实系统权限、双机同步和在线升级的验收边界见文末。

## 架构

```
swift/
├── Package.swift                 SwiftPM 包（macOS 12+）
├── Sources/
│   ├── StashCore/                与 UI 无关的核心层
│   │   ├── Models/               剪贴板条目、标签、模板、分类、筛选条件
│   │   ├── Database/             SQLite 封装、建表/迁移、仓储层
│   │   ├── Services/             内容识别、加密、iCloud 同步、设置、图标、更新、JSON
│   │   └── Utilities/            文本变换、格式化、快捷键、颜色、语法高亮
│   ├── StashUI/                  SwiftUI 界面层
│   │   ├── Panel/                主面板（列表 / 卡片 / 筛选栏 / 标签选择器）
│   │   ├── Preview/              预览面板（代码 / JSON / 颜色 / 图片 / Base64 …）
│   │   ├── Settings/             设置窗口 8 个分区
│   │   ├── Onboarding/           新手引导 6 步
│   │   ├── Widget/               桌面悬浮小组件
│   │   └── State/                视图模型、Toast、图标缓存
│   └── StashApp/                 AppKit 应用层
│       ├── AppDelegate.swift     生命周期与全局装配
│       ├── Windows/              主面板 / 设置 / 小组件窗口
│       └── Services/             剪贴板监听、粘贴、全局热键、队列、登录项
├── Scripts/
│   ├── build-app.sh              打包 Stash.app
│   └── generate-locales.py       由 JSON 生成 Swift 文案表
└── Tests/StashCoreTests/         单元测试（移植自原 JS 测试并扩充）
```

## 构建

```bash
cd swift
swift build            # 编译
swift test             # 跑核心、界面状态和应用服务回归测试（87 项）
./Scripts/build-app.sh # 生成 build/Stash.app
```

`build-app.sh` 会编译 Release 版本、组装 `Info.plist`（含 `LSUIElement`）、
拷贝图标与资源包，并对 bundle 签名。优先使用 `--sign` 或
`STASH_SIGN_IDENTITY` 指定的证书，其次复用本机 `.swiftpm/signing-identity`；
首次构建若仅有一张有效 Apple Development / Developer ID Application 证书，
会自动选择并保存。无法唯一选择时才使用 ad-hoc，并输出权限可能失效的警告。
正式分发时用 `--sign` 指定 Developer ID，并另行公证。

## 权限

| 权限 | 用途 | 是否必需 |
| --- | --- | --- |
| 辅助功能 | 把选中的内容粘贴回你正在使用的应用 | 必需（首次粘贴时提示） |
| 输入监控 | 当前实现不使用全局键监听 | 不需要 |

> 全局快捷键优先使用 Carbon `RegisterEventHotKey`（无需任何权限）；
> 应用获得焦点时补充本地键监听，不需要授予「输入监控」权限。

macOS 按代码签名身份识别授权，应用名称相同不代表能继承授权。
从旧版 Developer ID 或临时 ad-hoc 签名切换到本地开发者签名后，需要为当前
`build/Stash.app` 重新授权一次：在辅助功能中移除失效的同名条目，添加当前应用，
开启开关后重启。后续保持相同证书、bundle ID 和签名要求的构建可维持稳定身份；
构建脚本不会修改系统权限。

## 数据与兼容性

- 数据库位置：`~/Library/Application Support/Stash/data/zpaste.db`，**与 Electron 版完全一致**，
  升级后既有剪贴板历史、标签直接可用。旧模板数据保留用于格式兼容，不再提供模板界面。
- 表结构、索引、迁移逻辑与原版逐条对应（`StashCore/Database/Schema.swift`）。
- **旧版设置会自动导入**：启动时若本地没有设置，会从 Electron 的 Chromium
  `localStorage` 里恢复 `zpaste-settings`（`StashCore/Services/ElectronSettingsImporter.swift`）。
- 窗口布局模式沿用 `window-settings.json`，与旧版同一个文件。
- 内容加密使用 AES-256-GCM + PBKDF2-HMAC-SHA512，与旧版密文**互通**。
- iCloud 同步目录 `~/Library/Mobile Documents/com~apple~CloudDocs/ZPaste`，
  同步文件格式（明文 v1 / 加密 v2）保持不变。

## 文案

界面文案以 `swift/Resources/Locales/*.json` 为唯一事实来源，
`Scripts/generate-locales.py` 会把它们生成成 `StashCore/Services/Locales.swift`，
维护原生应用的三语文案；原生菜单新增的文案也维护在这些 JSON 中。修改 JSON 后重新执行该脚本即可。

```bash
python3 swift/Scripts/generate-locales.py
```

## 相对旧版的修复

对齐过程中发现并修复了若干旧版缺陷与实现差异：

1. **粘贴内容为空**：列表以 `includeContent=false` 载入，粘贴前会重新读取整行。
2. **标签筛选失效**：SQL 拼接时多行字符串丢失首个换行，`FROM … ci` 与 `JOIN` 粘在一起。
3. **新装缺表**：`sqlite3_prepare_v2` 只编译脚本的第一条语句，建表改用 `sqlite3_exec`。
4. **事务死锁**：事务内再调用 `execute/query` 会在同一串行队列上死锁，改为可重入锁。
5. **崩溃（数据竞争）**：视图模型在后台线程读取主线程正在修改的数组，改为 `@MainActor` 隔离。
6. **JSON 复制内容不同**：自研有序 JSON 序列化，输出与 `JSON.stringify(value, null, 2)` 逐字节一致。
7. **图片元数据格式**：宽高改为数字，与旧版一致；剪贴板图片统一转成 PNG 再哈希入库。
8. **面板按键串扰**：面板的键盘监听只在面板是焦点窗口时生效，设置窗口不再被抢键。
9. **修饰键快捷键失效**：`⌥` 这类纯修饰键以 `flagsChanged` 送达，现已纳入监听与录制。
10. **标题编辑无法提交**：编辑态独占 Enter/Escape，失焦自动保存。
11. **快速编辑为空**：先载入内容再打开编辑器，补上 ⌘Enter 保存与 Escape 取消。
12. **计数与来源应用列表过期**：新增/删除条目后同步刷新。
13. **面板重新打开不刷新**：隐藏期间捕获的新条目会按当前筛选重新加载。

## 有意保留的差异

以下差异均为旧版缺陷或原生实现更优之处，均在审计中逐条确认：

1. **模板功能已移除**：按 2026-10-22 的产品决定，原生版不再提供模板页签、列表和编辑器，已有数据保留。
2. **`T` 键打开标签选择器**：旧版因事件冒泡顺序导致该快捷键永远失效（先聚焦搜索框、
   再被输入框守卫拦下），新版按文档意图生效。
3. **快速编辑保存后粘贴编辑后的内容**：旧版会用旧内容覆盖编辑结果。
4. **双击不误粘贴**：旧版双击会先触发两次粘贴，现改为单击延迟判定，双击只打开编辑器。
5. **语法高亮**：旧版用 shiki（JS 运行时），现为自研分词器，支持检测器识别出的
   全部语言（TypeScript / JavaScript / Python / Rust / Go / Java / HTML / CSS / SQL / Shell）。
6. **颜色解析**：旧版不支持 4 位 `#RGBA`，其余 HEX / RGB / HSL 行为与旧版一致。
7. **Base64 解码**：旧版按 Latin-1 解码会产生乱码，现按 UTF-8 解码。
8. **粘贴方式**：旧版通过 `osascript` 模拟按键，现用 `CGEvent` 直接发送 ⌘V
   （因此需要给 Stash 自身授予「辅助功能」权限）。
9. **设置窗口可拖动、可缩放**：旧版无标题栏且无法拖动/缩放，现补上可拖动标题栏与
   500×400 最小尺寸。
10. **原生右键菜单**：旧版是自绘浮层，新版使用系统 `NSMenu`（外观不同，行为等价）。
11. **托盘左键**：旧版左键切换面板、右键出菜单；新版行为一致。


## 2026-10-21 修复与验收

本轮在已有 Swift 重写代码上修复了以下功能链路：

- 使用真实 macOS 虚拟键码注册全局快捷键；统一方向键、Escape、回车、Option 组合键和 F1–F20 的识别；区分 Control 与 Command；录制组合键时等待完整按键，不在第一个修饰键按下时提前结束。
- 设置窗口先保存内容再创建，修复首次打开空白；使用正确的窗口关闭回调；重复唤起面板时保留粘贴目标应用；支持原生菜单缩放和三语菜单标签。
- 搜索与类型、来源、标签筛选及排序组合；捕获新内容后继续遵守当前筛选；置顶、收藏、删除、计数和小组件状态依据数据库刷新；来源应用按 bundle ID 合并计数。
- 预览按条目重新加载，丢弃过期异步结果；修复图片预览复用和图片缓存增长；代码和 JSON 以连续文本排版。
- 用可命中的 SwiftUI 手势处理点击与双击，双击只打开编辑器；底部布局补全快速编辑入口；编辑器保留回车、Escape、⌘Enter、按钮保存及焦点；模板编辑不再被面板快捷键抢走输入。
- 剪贴板按 changeCount 处理一次，避免每 500ms 重复解码同一图片；重复复制图片也会通知界面；只在入库成功后发布新增事件。
- 粘贴前读取完整内容；图片读取失败时保留当前剪贴板；队列去重并防止短时间内覆盖尚未发出粘贴按键的内容；无辅助功能权限时不消耗队列。
- 小组件初始位置位于可见屏幕内；沿用“跟随筛选”设置；快捷键提示跟随前缀；关闭窗口不修改固定状态。
- “不限制”正确保存为 0；自动语言跟随系统；自动主题监听使用 DistributedNotificationCenter；保留时长进入定时清理，标签、收藏和置顶记录受保护。
- 同步导出覆盖超过 2000 条的历史；文件原子写入并使用唯一文件名；导出失败不前移检查点；导入整文件事务回滚，失败文件可重试；原地合并保留标签关系；旧标签迁移只执行一次。
- SQLite 正确保存包含 NUL 的文本，并串行化关闭与备份。已有数据库在新版首次运行时，先备份到 `~/Library/Application Support/Stash/backups/pre-native-repair.sqlite3`，再迁移。图片文件保留在原目录。
- 更新按版本号比较，按发布清单选择实际架构 ZIP，拒绝 HTTP 错误下载；安装前验证应用包，在原路径暂存和备份，替换或启动失败时回滚；修复退出安装的递归调用。
- 打包时拷贝正确的 SwiftPM 资源包，应用图标从包内加载，不再依赖开发机 `.build` 路径。

### 已通过

| 验证 | 结果 |
| --- | --- |
| `swift test` | 86 项通过，覆盖核心逻辑、面板状态、原生事件转换、应用服务、窗口、备份和同步故障恢复 |
| 原 Electron `node --test tests/*.test.mjs tests/panel/*.test.mjs` | 17 项通过 |
| 原 Electron `npm run typecheck` | 主进程与界面类型检查通过 |
| `python3 swift/Scripts/generate-locales.py --check` | 三语生成文件一致 |
| 真实 Swift 应用 | 设置窗口首次打开及关闭、搜索、来源与类型筛选、方向键更新预览、JSON 排版、三种布局切换、列表及底部卡片双击打开完整内容编辑器 |
| Release 包 | Apple Silicon 构建、包内图标资源、动态依赖和 `codesign --verify --deep --strict` 检查通过；Release 二进制在隔离配置下启动 |
| 加密互通 | 读取由原 Node AES-256-GCM / PBKDF2 参数生成的中文与 emoji 测试载荷，并完成加密往返 |
| 数据安全 | 临时 SQLite 数据库测试备份、标签保留、清理保护、导入失败回滚及重试；验收使用隔离数据库 |

历史验收日志保留在本机 Verification 目录，不随公开源码发布。当前 2.0 界面见 [新版截图](../docs/screenshots/2.0.0/README.md)，公开发布流程见 [发布说明](../docs/releasing.md)。

### 仍需外部环境验收

这些项目不能仅凭测试通过标记为“100%完成”：

- **真实跨应用粘贴、序列/批量/小组件粘贴**：隔离测试 App 尚未授予 macOS「辅助功能」权限；队列和完整内容读取已通过注入式测试，真实按键粘贴尚未通过验收。授权入口位于设置 → 隐私。
- **后台全局快捷键**：键码和匹配已有测试，应用内布局快捷键已实测；已退出原版并打开正常配置新版，仍需逐条验收系统级注册和跨应用触发。
- **iCloud 双机同步**：兼容文件、加密、事务和重试已在临时目录验证；未在两台已登录 iCloud 的 Mac 上验证上传、下载与离线恢复。
- **开机自启与在线升级**：实现已审查，未改动本机登录项，也未对已安装应用执行真实下载替换或重启安装。
- **平台与分发**：本机验证为 Apple Silicon / macOS 26.5；macOS 12 和 Intel 尚未实机验证。构建使用本机 Apple Development 证书，已验证修改包内容后签名要求保持一致；未做 Developer ID 公证。
- **旧设置恢复**：LevelDB 的恢复仍为尽力扫描，不能等同于完整 LevelDB 数据库读取器。数据库备份会保留历史；迁移后的设置应再与原版核对。

### 隔离复测

```bash
cd swift
Scripts/build-app.sh --debug --qa
```

生成 `build/Stash-QA.app`，通过 `LSEnvironment` 使用 `build/qa-profile` 中的独立数据库、设置文件和测试同步目录。该模式不注册登录项，也不自动检查更新。可在 `qa-profile/settings.json` 使用不与原版冲突的快捷键。

正常发布包使用 `Scripts/build-app.sh`，输出 `build/Stash.app`。替换运行中的应用前，应先退出其他 Stash 实例，避免它们同时监听剪贴板、竞争快捷键或继续使用旧代码写入数据库。
