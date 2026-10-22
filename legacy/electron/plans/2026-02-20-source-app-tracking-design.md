# 来源应用识别与筛选设计

## 概述

识别每条剪贴板记录来自哪个应用，并在面板中展示来源应用图标和名称，支持按来源应用筛选。

## 获取前台应用信息

- 剪贴板内容变化时，通过 `osascript` 获取前台应用名和 Bundle ID
- `source_app` 存储为 JSON：`{"name":"Visual Studio Code","bundleId":"com.microsoft.VSCode"}`
- 应用图标：通过 Bundle ID 找 .app 路径，读取 .icns 转 PNG，缓存到 `userData/app-icons/`

## FilterTabs 第三行

- 新增 `getSourceApps()` 查询，返回去重应用列表及记录数
- 每个标签：应用图标(16x16) + 应用名 + 数量角标
- 点击筛选，支持单选
- clipboardStore 新增 `sourceAppFilter: string | null`

## 列表项展示

- 底部信息行追加：`[icon 12x12] 应用名`
- source_app 为 null 时不显示
- 图标 renderer 端 Map 缓存

## IPC 接口

- `sourceApps:getAll` → `{ name, bundleId, count }[]`
- `sourceApps:getIcon` → `string` (base64 PNG)
