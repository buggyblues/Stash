# Stash 自动发布与热更新设计文档

日期：2026-02-28

## 背景

Stash 是一个 macOS 专属的 Electron 剪贴板管理应用，当前版本 1.0.1，使用 electron-builder 构建，尚无 CI/CD 流水线和自动更新机制。本文档描述基于 GitHub Releases 的自动发布和热更新方案。

## 目标

1. 推送 git tag 后自动构建并发布到 GitHub Releases
2. 用户打开 App 时自动检查新版本，发现更新立即弹出提示
3. 用户确认后后台下载，下载完成后提示重启安装

## 方案选型

采用 **electron-updater + GitHub Releases** 方案：

- electron-builder 官方配套，天然集成，改动最小
- GitHub Releases 免费存储构建产物
- `latest-mac.yml` 作为版本描述文件，包含版本号、sha512 校验、文件大小
- 暂时跳过代码签名（后续补充 Apple Developer 证书）

## 整体架构

```
开发者推送 v1.x.x tag
        │
        ▼
GitHub Actions (macOS runner)
        │
   npm ci + npm run build:mac
        │
   electron-builder 生成：
   ├── Stash-X.Y.Z-arm64.dmg
   ├── Stash-X.Y.Z-x64.dmg
   └── latest-mac.yml
        │
   gh release create + upload
        │
        ▼
GitHub Releases（公开）
        │
        ▼
用户端 App（electron-updater）
   启动 / 每小时检查
        │
   拉取 latest-mac.yml 对比版本号
        │
   发现新版本 → 对话框提示
        │
   用户确认 → 后台下载 → sha512 校验 → 退出安装重启
```

## 变更文件清单

### 1. `package.json`
- 添加 `electron-updater` 到 `dependencies`

### 2. `electron-builder.yml`
- 添加 `publish` 配置，指定 provider 为 `github`，填写 owner 和 repo

### 3. `src/main/index.ts`
- 导入 `autoUpdater` from `electron-updater`
- 新增 `setupAutoUpdater()` 函数
- 在 `app.whenReady()` 后调用（仅 `app.isPackaged` 时生效）

#### autoUpdater 配置：
- `autoDownload = false`：用户确认后再下载
- `autoInstallOnAppQuit = true`：退出时自动安装已下载的更新
- 检查频率：启动时 + 每小时一次

#### 事件处理：
- `update-available`：弹出对话框，用户选择"立即更新"或"稍后提醒"
- `update-downloaded`：弹出对话框，用户选择"现在重启"或"稍后"
- `error`：静默记录日志，不弹错误弹窗

### 4. `.github/workflows/release.yml`（新建）
- 触发条件：`push` 到 `v*` tag
- Runner：`macos-latest`
- 步骤：checkout → Node.js 22 → npm ci → build:mac → create release → upload assets
- 所需 Secret：`GITHUB_TOKEN`（Actions 自动提供）

## GitHub Actions 流水线

```yaml
# 触发：git push origin v1.x.x
on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: macos-latest
    steps:
      - checkout
      - setup Node.js 22
      - npm ci
      - npm run build:mac
      - gh release create ${{ github.ref_name }} --generate-notes
      - gh release upload dist/*.dmg dist/latest-mac.yml
```

## 版本管理约定

遵循 SemVer：
- `vX.Y.Z` Z+1：bug fix
- `vX.Y.Z` Y+1：新功能
- `vX.Y.Z` X+1：重大变更

发布 checklist：
1. 更新 `package.json` 的 `version` 字段
2. `npm run build` 确保通过
3. commit 所有改动
4. `git tag v1.x.x && git push origin v1.x.x`

## 后续扩展

- 补充 Apple Developer 证书配置（`CSC_LINK`、`CSC_KEY_PASSWORD`、`APPLE_ID` 等 Secrets）
- 如需国内访问加速，可在方案基础上叠加 `update.electronjs.org` 代理层
