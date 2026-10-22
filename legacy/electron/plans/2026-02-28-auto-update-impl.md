# Auto-Update & GitHub Releases Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 Stash 添加基于 GitHub Releases 的自动发布 CI/CD 流水线和应用内热更新功能。

**Architecture:** 使用 `electron-updater` 检查/下载/安装更新，GitHub Actions 在推送 `v*` tag 时自动构建并发布到 GitHub Releases，`electron-builder` 生成的 `latest-mac.yml` 作为版本描述文件。

**Tech Stack:** electron-updater, electron-builder (已有), GitHub Actions, GITHUB_TOKEN (Actions 自带)

---

### Task 1: 安装 electron-updater 依赖

**Files:**
- Modify: `package.json`

**Step 1: 安装依赖**

```bash
npm install electron-updater
```

**Step 2: 验证安装成功**

```bash
node -e "require('electron-updater'); console.log('ok')"
```

Expected: 输出 `ok`，无报错

**Step 3: Commit**

```bash
git add package.json package-lock.json
git commit -m "chore: add electron-updater dependency"
```

---

### Task 2: 配置 electron-builder publish 字段

**Files:**
- Modify: `electron-builder.yml`

**Step 1: 读取当前文件内容（已读过，直接编辑）**

在 `electron-builder.yml` 末尾添加 `publish` 配置。注意将 `<YOUR_GITHUB_USERNAME>` 替换为实际 GitHub 用户名（从 `package.json` 的 `homepage` 字段可以看出是 `perseveringman`）：

```yaml
publish:
  provider: github
  owner: perseveringman
  repo: z-paste
```

**Step 2: 验证 YAML 语法正确**

```bash
node -e "const yaml = require('js-yaml'); yaml.load(require('fs').readFileSync('electron-builder.yml', 'utf8')); console.log('ok')"
```

Expected: 输出 `ok`（若 js-yaml 不存在可跳过此验证，直接看构建）

**Step 3: Commit**

```bash
git add electron-builder.yml
git commit -m "chore: configure electron-builder publish to github releases"
```

---

### Task 3: 在主进程中集成 autoUpdater

**Files:**
- Modify: `src/main/index.ts`

**Step 1: 在文件顶部添加 import**

在 `src/main/index.ts` 第 1 行现有 import 后追加：

```typescript
import { autoUpdater } from 'electron-updater'
import { dialog } from 'electron'
```

注意：`dialog` 已从 `electron` 导入（当前第 1 行只导入了 `app, BrowserWindow, ipcMain, clipboard`），需要将 `dialog` 加入现有导入语句。

**Step 2: 添加 setupAutoUpdater 函数**

在 `app.whenReady().then(...)` 之前，添加以下函数：

```typescript
function setupAutoUpdater(): void {
  // 开发模式下跳过
  if (!app.isPackaged) return

  autoUpdater.autoDownload = false
  autoUpdater.autoInstallOnAppQuit = true

  autoUpdater.on('update-available', (info) => {
    dialog.showMessageBox({
      type: 'info',
      title: '发现新版本',
      message: `Stash ${info.version} 已发布`,
      detail: '是否立即下载更新？下载完成后重启即可安装。',
      buttons: ['立即更新', '稍后提醒'],
      defaultId: 0,
      cancelId: 1,
    }).then(({ response }) => {
      if (response === 0) {
        autoUpdater.downloadUpdate().catch(() => {
          // 下载失败静默处理，不打扰用户
        })
      }
    })
  })

  autoUpdater.on('update-downloaded', () => {
    dialog.showMessageBox({
      type: 'info',
      title: '更新已准备好',
      message: '新版本已下载完成',
      detail: '重启 Stash 以完成安装。',
      buttons: ['现在重启', '稍后'],
      defaultId: 0,
      cancelId: 1,
    }).then(({ response }) => {
      if (response === 0) {
        autoUpdater.quitAndInstall()
      }
    })
  })

  autoUpdater.on('error', () => {
    // 静默失败，不弹错误弹窗
  })

  // 启动时检查，之后每小时一次
  autoUpdater.checkForUpdates().catch(() => {})
  setInterval(() => {
    autoUpdater.checkForUpdates().catch(() => {})
  }, 60 * 60 * 1000)
}
```

**Step 3: 在 app.whenReady() 内调用**

在 `app.whenReady().then(() => {` 块内，`clipboardMonitor.start()` 那行之后，添加调用：

```typescript
  setupAutoUpdater()
```

**Step 4: 验证 TypeScript 编译通过**

```bash
npm run typecheck
```

Expected: 无报错

**Step 5: Commit**

```bash
git add src/main/index.ts
git commit -m "feat: integrate electron-updater for auto-update"
```

---

### Task 4: 创建 GitHub Actions 发布流水线

**Files:**
- Create: `.github/workflows/release.yml`

**Step 1: 创建目录并写入文件**

创建 `.github/workflows/release.yml`，内容如下：

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: macos-latest

    permissions:
      contents: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build:mac
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Create GitHub Release
        run: |
          gh release create "${{ github.ref_name }}" \
            --title "${{ github.ref_name }}" \
            --generate-notes
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Upload release assets
        run: |
          gh release upload "${{ github.ref_name }}" \
            dist/*.dmg \
            dist/latest-mac.yml
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Step 2: 验证 YAML 格式（目视检查缩进正确）**

检查 `on.push.tags` 有正确的 `- 'v*'` 格式，`permissions.contents: write` 存在（上传 Release 需要此权限）。

**Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: add github actions release workflow"
```

---

### Task 5: 端到端验证发布流程

**Step 1: 确认 package.json version 字段是否需要更新**

检查当前 `package.json` 的 `version` 是否是 `1.0.1`。如果是，可以先用这个版本测试，或根据需要更新。

**Step 2: 本地构建验证**

```bash
npm run build:mac
```

Expected:
- `dist/` 目录下生成 `stash-X.Y.Z-arm64.dmg`、`stash-X.Y.Z-x64.dmg`
- `dist/latest-mac.yml` 文件存在

**Step 3: 检查 latest-mac.yml 内容**

```bash
cat dist/latest-mac.yml
```

Expected: 包含 `version`、`files`（含 `sha512`、`size`）、`releaseDate` 等字段

**Step 4: 推送 tag 触发 CI**

```bash
# 确保所有改动已 commit
git status

# 创建并推送 tag（使用当前 package.json 中的版本号）
git tag v1.0.1
git push origin v1.0.1
```

**Step 5: 检查 Actions 运行状态**

在 GitHub 仓库页面 → Actions → Release workflow 查看运行状态。

Expected: 所有 steps 绿色通过，GitHub Releases 页面出现 `v1.0.1` release，包含 2 个 .dmg 和 latest-mac.yml。

---

## 后续（可选，当有 Apple Developer 证书时）

在 `electron-builder.yml` 的 `mac` 部分补充签名配置，并在 GitHub Secrets 中添加：
- `CSC_LINK`：base64 编码的 .p12 证书
- `CSC_KEY_PASSWORD`：证书密码
- `APPLE_ID`：Apple ID 邮箱
- `APPLE_APP_SPECIFIC_PASSWORD`：App 专用密码（用于 Notarize）
- `APPLE_TEAM_ID`：Team ID

将 `electron-builder.yml` 的 `notarize: false` 改为 `notarize: true`。
