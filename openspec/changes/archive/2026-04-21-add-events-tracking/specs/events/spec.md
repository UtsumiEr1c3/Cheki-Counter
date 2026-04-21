## ADDED Requirements

### Requirement: 活动实体与存储

系统 SHALL 使用独立 `events` 表持久化活动,字段为 `id (自增主键), name (活动名), venue (场地), date (演出日期 YYYY-MM-DD), created_at (录入时间戳)`。`(name, venue, date)` 三元组 MUST 唯一,重复创建 MUST 复用已有行而非插入新行。活动可以没有任何关联的 `records`(纯打卡场景)。

#### Scenario: 同名活动不同日期视为不同活动

- **WHEN** 已有 `events` 行 `('定期公演', '武汉电切', '2026-03-15')`,用户新建 `('定期公演', '武汉电切', '2026-04-19')`
- **THEN** 系统插入第二行;两行并存

#### Scenario: 同日同场地不同活动名视为不同活动

- **WHEN** 已有 `('VoltFes 2.0', '武汉MAO', '2026-04-20')`,用户新建 `('VoltFes 2.0 夜公演', '武汉MAO', '2026-04-20')`
- **THEN** 系统插入第二行;代表同日的昼/夜两场

#### Scenario: 三元组完全相同复用已有行

- **WHEN** 用户通过 AddEventDialog 或 AddRecordDialog 提交 `('定期公演', '武汉电切', '2026-03-15')`,而该三元组已存在
- **THEN** 系统 NOT 插入新行,`AddEventDialog` 返回已有 `event.id`

#### Scenario: 活动可独立于切奇记录存在

- **WHEN** 用户通过"新建活动(无偶像)"入口创建 `('定期公演', '北京电切', '2026-03-15')`
- **THEN** `events` 表新增该行,`records` 表无任何新增

### Requirement: 新建活动入口(无偶像)

系统 SHALL 在首页右下角 `+` 提供"新建活动(无偶像)"入口。点击 SHALL 打开 `AddEventDialog`,包含活动名、场地、演出日期三个必填字段。场地字段 SHALL 沿用 `records` 的"可打字 + 历史下拉"控件行为(UNION `records.venue` 与 `events.venue` 作为历史来源,按最近使用时间降序)。提交 SHALL 执行活动三元组 upsert 语义。

#### Scenario: 首页 FAB 展开为菜单

- **WHEN** 用户点击首页右下角 `+`
- **THEN** 系统 SHALL 展开菜单,包含"新建偶像"和"新建活动(无偶像)"两个子项

#### Scenario: 活动名必填

- **WHEN** 用户在 AddEventDialog 未填活动名点击提交
- **THEN** 系统拒绝提交并显示"请填写活动名"

#### Scenario: 场地必填

- **WHEN** 用户在 AddEventDialog 未填场地点击提交
- **THEN** 系统拒绝提交并显示"请填写场地"

#### Scenario: 日期默认为今天

- **WHEN** AddEventDialog 首次打开
- **THEN** 日期字段预填为设备当前日期(YYYY-MM-DD)

#### Scenario: 场地字段历史下拉 UNION 两表

- **WHEN** 用户在 AddEventDialog 聚焦场地字段且输入为空,且 `records.venue` 中曾用过 `'武汉电切'`、`events.venue` 中曾用过 `'北京电切'`
- **THEN** 下拉 SHALL 同时包含两者,去重(DISTINCT),按最近一次使用时间降序

#### Scenario: 三元组已存在时提示复用

- **WHEN** 用户提交 `('定期公演', '武汉电切', '2026-03-15')`,该三元组已在 `events` 中存在
- **THEN** 系统 NOT 弹错误;dialog 关闭后界面回到上一页(不新增,用户感知为"这个活动已记录过")

### Requirement: 偶活总览入口与列表

系统 SHALL 在 AppBar 右上角"统计"图标旁新增"偶活总览"入口图标。入口打开 `EventsOverviewPage`,以 `ListView` 纵向堆叠所有活动卡片,按演出日期(`events.date`)降序排列。每张卡片 SHALL 展示:日期 + 场地(首行)、活动名(第二行)、切奇偶像摘要(第三行,无切奇时显示"(未切奇)")、当场小计金额(右下,无切奇时显示"—")。页面底部 SHALL 显示汇总:总活动数 / 有切奇活动数 / 切奇总金额。页面 SHALL 支持年份过滤下拉(复用 `year-filter-hide-empty` 规范)。

#### Scenario: 按演出日期降序排列

- **WHEN** `events` 表有日期为 `2026-04-20`、`2026-03-15`、`2025-12-31` 的三条
- **THEN** 总览页按此顺序从上到下显示

#### Scenario: 纯打卡活动显示未切奇

- **WHEN** 某 `event` 没有任何 `records` 关联
- **THEN** 该卡片第三行 SHALL 显示"(未切奇)",右下金额显示"—"

#### Scenario: 切奇偶像摘要格式

- **WHEN** 某 `event` 关联的 records 为:小五 ×3、桃子 ×2
- **THEN** 第三行 SHALL 显示"小五 ×3 · 桃子 ×2",右下 SHALL 显示 `¥` + 当场 records 的 `subtotal` 合计

#### Scenario: 年份过滤隐藏无活动的年

- **WHEN** 用户展开年份下拉
- **THEN** 下拉仅列出 `events.date` 中存在的年份(外加"全部")

#### Scenario: 底部汇总计数

- **WHEN** 当前过滤下有 12 个活动,其中 9 个有 records,records 合计 ¥2,450
- **THEN** 底部 SHALL 显示"12 场 · 9 场有切奇 · ¥2,450"

### Requirement: 活动详情页

系统 SHALL 在偶活总览卡片被点击时打开 `EventDetailPage`,展示活动信息(活动名、场地、日期)和该活动关联的所有 `records`,records SHALL 按偶像分组(同一偶像的多条 records 归在一起显示),组内按 `records.created_at` 升序。纯打卡活动 SHALL 显示"暂无切奇记录"的空态提示。详情页 SHALL 提供返回按钮回到总览。

#### Scenario: 有切奇的活动展示分组

- **WHEN** 某活动关联的 records 为:小五 ×3 三条 + 桃子 ×2 两条
- **THEN** 详情页 SHALL 分两组显示,每组内列出该偶像的所有 records 条目

#### Scenario: 纯打卡活动空态

- **WHEN** 用户点击"(未切奇)"的活动卡片
- **THEN** 详情页 SHALL 展示活动信息,records 区域显示"暂无切奇记录"

### Requirement: 活动无编辑删除 UI

本版本 SHALL NOT 提供活动的编辑或删除 UI。用户如需修正错填的活动名,SHALL 通过新建一个正确的活动并在后续切奇时选择它来绕行;错填的活动行将在 DB 中保留(除非未来版本提供清理工具)。

#### Scenario: 详情页不提供编辑删除操作

- **WHEN** 用户长按或查看活动详情页
- **THEN** 页面 NOT 展示"编辑活动"或"删除活动"按钮
