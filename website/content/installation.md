---
title: 安装指南
---

# 安装指南

## 系统要求

- macOS 12 Monterey 或更高版本
- Apple Silicon（M1/M2/M3）或 Intel 处理器

## 下载安装

### 从 GitHub Releases 下载

1. 访问 [GitHub Releases](https://github.com/perseveringman/Stash/releases/latest) 页面
2. 根据您的处理器架构下载对应版本：
   - **Apple Silicon（M 系列芯片）**：下载 `z-paste-x.x.x-arm64.dmg`
   - **Intel 处理器**：下载 `z-paste-x.x.x-x64.dmg`
3. 打开下载的 `.dmg` 文件
4. 将 **Z-Paste** 图标拖入 **Applications** 文件夹

### 如何判断处理器类型

点击左上角苹果菜单 → **关于本机**，查看「芯片」或「处理器」字段。

## 首次启动

1. 打开 **Launchpad** 或 **Applications** 文件夹，点击 **Z-Paste** 启动
2. macOS 可能提示「无法验证开发者」，请按以下步骤处理：
   - 打开 **系统设置** → **隐私与安全性**
   - 在底部找到「Z-Paste 已被阻止」，点击 **仍然打开**
3. 启动后会进入引导页面，按提示完成初始设置

## 授予权限

Z-Paste 需要以下权限才能正常工作：

| 权限 | 用途 | 是否必须 |
|---|---|---|
| 辅助功能（Accessibility） | 自动粘贴到其他应用 | 必须 |
| 输入监控（Input Monitoring） | 监听全局快捷键 | 必须 |

首次触发相关功能时，macOS 会弹出权限申请弹窗，点击「打开系统设置」后在对应权限列表中勾选 **Z-Paste**。

## 开机自启

在 Z-Paste 的「设置」页面可以开启「登录时启动」，Z-Paste 会在菜单栏静默运行，不会弹出主窗口。

## 卸载

将 `/Applications/Z-Paste.app` 移入废纸篓即可。用户数据（剪切板历史）存储在：

```
~/Library/Application Support/Z-Paste/
```

如需彻底清除数据，请同时删除该目录。
