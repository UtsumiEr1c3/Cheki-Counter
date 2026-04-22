## MODIFIED Requirements

### Requirement: 偶活总览入口与列表

系统 SHALL 在 AppBar 右上角"统计"图标旁新增"偶活总览"入口图标。入口打开 `EventsOverviewPage`,以 `ListView` 纵向堆叠所有活动卡片,按演出日期(`events.date`)降序排列。偶活总览 SHALL 过滤掉任何包含 `is_online = 1` 记录的 event(即:只要一个 event 关联了任意一条电切记录,该 event 在总览中整场隐藏,不论是否同时也有现场记录)。每张卡片 SHALL 展示:日期 + 场地(首行)、活动名(第二行)、切奇偶像摘要(第三行,无切奇时显示"(未切奇)")、当场小计金额(右下,无切奇时显示"—")。卡片内的切奇偶像摘要与当场小计 SHALL 只统计 `is_online = 0` 的记录(在未被过滤掉的 events 中,若有混入电切记录,电切不计入摘要与金额)。页面底部 SHALL 显示汇总:总活动数 / 有切奇活动数 / 切奇总金额。页面 SHALL 支持年份过滤下拉(复用 `year-filter-hide-empty` 规范)。

#### Scenario: 按演出日期降序排列

- **WHEN** `events` 表有日期为 `2026-04-20`、`2026-03-15`、`2025-12-31` 的三条,且均无电切记录
- **THEN** 总览页按此顺序从上到下显示

#### Scenario: 含电切记录的活动整场隐藏

- **WHEN** 某 event `'3rd Anniversary 特典会'` 关联的 records 全部 `is_online = 1`
- **THEN** 总览页 NOT 显示该活动卡片

#### Scenario: 同活动混合现场与电切也整场隐藏

- **WHEN** 某 event 关联 2 条现场记录与 1 条电切记录
- **THEN** 该活动 SHALL 从总览中整场隐藏(按"任一电切则隐藏"规则)

#### Scenario: 纯打卡活动显示未切奇

- **WHEN** 某 `event` 没有任何 `records` 关联
- **THEN** 该卡片第三行 SHALL 显示"(未切奇)",右下金额显示"—"

#### Scenario: 切奇偶像摘要仅统计现场记录

- **WHEN** 某 `event` 关联的 records 为:小五 ×3 现场 + 桃子 ×2 现场 + 小五 ×1 电切 —— 由于包含电切,该 event 本身会被整场隐藏
- **THEN** 卡片 NOT 渲染

#### Scenario: 全现场活动的切奇偶像摘要格式

- **WHEN** 某 `event` 关联的 records 全部 `is_online = 0`,偶像分布为小五 ×3、桃子 ×2
- **THEN** 卡片第三行 SHALL 显示"小五 ×3 · 桃子 ×2",右下 SHALL 显示 `¥` + 这些现场 records 的 `subtotal` 合计

#### Scenario: 年份过滤隐藏无活动的年

- **WHEN** 用户展开年份下拉
- **THEN** 下拉仅列出 `events.date` 中存在的年份(外加"全部")

#### Scenario: 底部汇总计数仅统计未被过滤的活动

- **WHEN** 数据库内 15 个 events,其中 3 个含电切记录被隐藏,剩余 12 个中 9 个有现场 records,现场 records 合计 ¥2,450
- **THEN** 底部 SHALL 显示"12 场 · 9 场有切奇 · ¥2,450"
