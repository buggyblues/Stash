---
title: 安装指南
---

# 安装 Stash 2.0

Stash 2.0 使用 Swift、SwiftUI 与 AppKit，支持 macOS 12 或更高版本。macOS 26 及更新系统使用原生 Liquid Glass；较早系统使用系统材质。

## 下载

- [Apple Silicon 安装包](https://release.zyb.world/Stash/releases/v2.0.0/Stash-2.0.0-arm64.dmg)
- [Intel 安装包](https://release.zyb.world/Stash/releases/v2.0.0/Stash-2.0.0-x64.dmg)
- [GitHub Releases 与校验值](https://github.com/buggyblues/Stash/releases/latest)

在苹果菜单的「关于本机」查看芯片类型，选择对应安装包。打开 DMG，将 Stash 拖入 Applications，然后启动 `/Applications/Stash.app`。

## 首次使用

Stash 常驻菜单栏，按 **⇧⌘V** 打开剪贴板面板。在「系统设置 → 隐私与安全性 → 辅助功能」允许 Stash，才能自动粘贴到其他应用。全局快捷键通过 macOS 的系统热键注册，不要求输入监控权限。

在「设置 → 通用」可选择中央、侧边或底部布局，以及登录时启动。若快捷键与其他应用冲突，可在「设置 → 快捷键」更改。

## 卸载

退出 Stash 后，将 `/Applications/Stash.app` 移入废纸篓。历史和设置保存在 `~/Library/Application Support/Stash/`。删除该目录会永久清除本机数据。

Electron 1.x 已废弃；当前安装包、构建流程和更新均使用原生 Swift 版本。
