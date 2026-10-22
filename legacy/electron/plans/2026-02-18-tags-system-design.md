# Stash 标签系统设计（简化交互）

日期：2026-02-18  
状态：已评审确认（Brainstorming）

## 1. 目标与原则

- 标签是用户主动归档，不做系统自动猜测归类。
- 鼓励 5-10 个高层级标签，抑制标签膨胀。
- `Starred` 是未分类收件箱，不是长期分类体系。
- 筛选支持双维度叠加：左侧栏筛选 + 顶部类型筛选。

## 2. 已确认产品决策

- 数据模型：采用关系模型（`tags` + `clipboard_item_tags`）。
- 首版范围：完整交付（含相似标签建议、15+ 软限制、设置页治理）。
- 筛选体系：保留左栏与顶部类型 Tabs，两者可叠加。
- 标签筛选语义：左栏标签单选。
- 命名策略：大小写不敏感唯一；存储统一为小写 slug。
- Star/Tag 关系：加任意标签后自动取消 Star（Star 作为未分类收件箱）。

## 3. 信息架构与交互

### 3.1 左侧栏（极简）

- `All Clips`
- `Starred (count)`
- `TAGS`
  - `work (count)`
  - `snippets (count)`
  - ...

说明：
- 左栏用于全局筛选维度（`all | starred | tag:<slug>`）。
- 顶部类型 Tabs 保留为内容类型维度（`text/code/url/json/...`）。
- 最终结果 = 左栏条件 AND 类型条件 AND 搜索词条件。

### 3.2 打标签入口

- 主入口：选中条目后按 `T` 打开 Spotlight 风格 `TagPicker`。
- 辅入口：列表项 hover 显示标签图标，点击打开同一 `TagPicker`。
- 拖拽入口：将条目拖到左侧某标签，直接应用该标签。

`TagPicker` 行为：
- 支持 `Cmd+Click` 多选标签。
- 输入新标签名后回车：立即创建并应用。
- 输入时若存在相似标签，展示建议：
  - `Use "snippets"`
  - `Create "codes"`

### 3.3 视觉标记

- 有标签条目：显示 `🏷️` 标记。
- Starred 条目：显示 `⭐` 标记。
- 普通条目：无额外标记。

## 4. 数据模型与迁移

## 4.1 新增表

```sql
CREATE TABLE IF NOT EXISTS tags (
  id           TEXT PRIMARY KEY,
  slug         TEXT NOT NULL UNIQUE,
  name         TEXT NOT NULL,
  created_at   INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL,
  last_used_at INTEGER
);

CREATE TABLE IF NOT EXISTS clipboard_item_tags (
  item_id      TEXT NOT NULL,
  tag_id       TEXT NOT NULL,
  created_at   INTEGER NOT NULL,
  PRIMARY KEY (item_id, tag_id),
  FOREIGN KEY (item_id) REFERENCES clipboard_items(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id)  REFERENCES tags(id) ON DELETE CASCADE
);
```

补充索引：
- `tags(slug)`
- `clipboard_item_tags(item_id)`
- `clipboard_item_tags(tag_id)`

## 4.2 slug 规则

- 统一小写。
- 空格转 `-`。
- 去除首尾分隔符与重复 `-`。
- 唯一性按 slug 判定（大小写不敏感）。

## 4.3 迁移路径

1. 上线新表与新 API，保留旧 `clipboard_items.tags` 字段兼容读取。
2. 启动时回填：将旧字段解析入新关联表。
3. 全量切换到新模型后，旧字段仅兜底只读，后续版本移除。

## 5. 业务规则

## 5.1 Star/Tag 联动

- 任何条目应用了至少 1 个标签后，自动 `is_favorite = 0`。
- 有标签条目不可置星（可提示“已归档，移除标签后可加星”）。

## 5.2 三层保留策略

- 有标签：永久保留。
- Starred：永久保留（设置页可做过期星标清理）。
- 普通历史：遵循 retention（如 30 天）。

## 6. 治理与防膨胀

- 软限制提示：标签数量超过 15 时，左栏 TAGS 顶部提示“标签太多会降低效率，考虑合并类似标签？”。
- 设置页统计：展示“总标签数”和“仅 1 条内容标签数”。
- 设置页管理操作：
  - `Rename`
  - `Delete`
  - `Merge into...`

Merge 要求：
- 事务内完成映射迁移、去重、更新 `last_used_at`、删除旧标签。

## 7. API 与查询契约

建议统一查询参数：

```ts
type GetItemsFilter = {
  leftFilter: { type: 'all' } | { type: 'starred' } | { type: 'tag'; slug: string }
  typeFilter?: string
  query?: string
  limit?: number
  offset?: number
}
```

写操作核心：
- `applyTags(itemId: string, slugs: string[]): Promise<void>`
- `removeTag(itemId: string, slug: string): Promise<void>`
- `listTagsWithCounts(): Promise<Array<{ slug: string; name: string; count: number }>>`
- `mergeTag(sourceSlug: string, targetSlug: string): Promise<void>`
- `renameTag(slug: string, nextName: string): Promise<void>`

## 8. 实施切片（同版本分层推进）

### 切片 1：数据层与查询层

- 新表、索引、迁移与回填。
- 仓储层标签 CRUD、映射操作、组合筛选查询。
- Star/Tag 联动和 retention 规则改造。

### 切片 2：核心交互

- 左侧栏 `All/Starred/Tags` + 计数。
- `TagPicker`（`T`、hover 入口、Cmd+Click、多选、新建即应用）。
- 拖拽到左栏标签打标签。

### 切片 3：治理与管理

- 相似标签建议。
- 标签数 > 15 软提示。
- 设置页 `Tag Management`（Rename/Delete/Merge/统计/一键清理低价值标签）。

## 9. 测试策略

- 仓储层单测：
  - applyTags 幂等
  - 自动取消 Star
  - merge/rename/delete 正确性
  - 组合筛选 SQL 语义正确
- IPC 集成测试：
  - 左栏筛选与类型筛选叠加
  - TagPicker 新建并应用链路
- 渲染层交互测试：
  - `T` 唤起与键盘操作
  - Cmd+Click 多选
  - 拖拽落到标签
  - 15+ 提示与相似建议

## 10. 验收标准

- 用户可通过 `T` 在 2 步内给条目打标签（打开选择器 + 选择/新建）。
- 左栏与类型 Tabs 可叠加筛选且结果稳定可预期。
- 已打标签条目自动退出 Starred。
- 设置页可完成标签 Rename/Delete/Merge 且数据一致。
- 超过 15 个标签时出现软提示，且不阻断操作。
