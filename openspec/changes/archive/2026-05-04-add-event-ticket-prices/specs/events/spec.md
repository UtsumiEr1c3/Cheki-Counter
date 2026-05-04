## MODIFIED Requirements

### Requirement: 活动实体与存储

系统 SHALL 使用独立 `events` 表持久化活动,字段为 `id (自增主键), name (活动名), venue (场地), date (演出日期 YYYY-MM-DD), created_at (录入时间戳), ticket_price (门票价格,非负整数)`。`ticket_price` SHALL 默认为 0,表示未记录门票价格或免费票。`(name, venue, date)` 三元组 MUST 唯一,重复创建 MUST 复用已有行而非插入新行。活动可以没有任何关联的 `records`(纯打卡场景)。

#### Scenario: 同名活动不同日期视为不同活动

- **WHEN** 已有 `events` 行 `('定期公演', '武汉电切', '2026-03-15', ticket_price=120)`,用户新建 `('定期公演', '武汉电切', '2026-04-19', ticket_price=150)`
- **THEN** 系统插入第二行;两行并存且各自保留自己的 `ticket_price`

#### Scenario: 同日同场地不同活动名视为不同活动

- **WHEN** 已有 `('VoltFes 2.0', '武汉MAO', '2026-04-20', ticket_price=180)`,用户新建 `('VoltFes 2.0 夜公演', '武汉MAO', '2026-04-20', ticket_price=220)`
- **THEN** 系统插入第二行;代表同日的昼/夜两场,门票价格分别保存

#### Scenario: 三元组完全相同复用已有行

- **WHEN** 用户通过 AddEventDialog 或 AddRecordDialog 提交 `('定期公演', '武汉电切', '2026-03-15')`,而该三元组已存在
- **THEN** 系统 NOT 插入新行,`AddEventDialog` 返回已有 `event.id`

#### Scenario: 已有活动门票价格为 0 时可补写

- **WHEN** 已有 event `('定期公演', '武汉电切', '2026-03-15', ticket_price=0)`,用户再次提交同三元组且门票价格为 120
- **THEN** 系统 SHALL 复用已有 event,并将该 event 的 `ticket_price` 更新为 120

#### Scenario: 已有活动非零门票价格不被覆盖

- **WHEN** 已有 event `('定期公演', '武汉电切', '2026-03-15', ticket_price=120)`,用户再次提交同三元组且门票价格为 150
- **THEN** 系统 SHALL 复用已有 event,并保持该 event 的 `ticket_price = 120`

#### Scenario: 活动可独立于切奇记录存在

- **WHEN** 用户通过"新建活动(无偶像)"入口创建 `('定期公演', '北京电切', '2026-03-15', ticket_price=100)`
- **THEN** `events` 表新增该行,`records` 表无任何新增

#### Scenario: 老数据迁移默认门票价格为 0

- **WHEN** DB 从旧版本升级到包含 `ticket_price` 的版本
- **THEN** 所有既有 `events` 行的 `ticket_price` SHALL 为 0

### Requirement: 新建活动入口(无偶像)

系统 SHALL 在首页右下角 `+` 提供"新建活动(无偶像)"入口。点击 SHALL 打开 `AddEventDialog`,包含活动名、场地、演出日期三个必填字段,以及门票价格一个可选字段。门票价格字段留空 SHALL 按 0 提交;填写时 MUST 为非负整数。场地字段 SHALL 沿用 `records` 的"可打字 + 历史下拉"控件行为(UNION `records.venue` 与 `events.venue` 作为历史来源,按最近使用时间降序)。提交 SHALL 执行活动三元组 upsert 语义,并按活动实体的门票价格补写规则处理 `ticket_price`。

#### Scenario: 首页 FAB 展开为菜单

- **WHEN** 用户点击首页右下角 `+`
- **THEN** 系统 SHALL 展开菜单,包含"新建偶像"和"新建活动(无偶像)"两个子项

#### Scenario: 活动名必填

- **WHEN** 用户在 AddEventDialog 未填活动名点击提交
- **THEN** 系统拒绝提交并显示"请填写活动名"

#### Scenario: 场地必填

- **WHEN** 用户在 AddEventDialog 未填场地点击提交
- **THEN** 系统拒绝提交并显示"请填写场地"

#### Scenario: 门票价格可为空

- **WHEN** 用户在 AddEventDialog 填完活动名、场地、日期,门票价格留空并提交
- **THEN** 系统 SHALL 创建或复用活动,新活动的 `ticket_price = 0`

#### Scenario: 门票价格必须为非负整数

- **WHEN** 用户在 AddEventDialog 将门票价格填写为负数或非数字
- **THEN** 系统拒绝提交并在门票价格字段下方显示错误提示

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

系统 SHALL 在 AppBar 右上角"统计"图标旁新增"偶活总览"入口图标。入口打开 `EventsOverviewPage`,以 `ListView` 纵向堆叠所有活动卡片,按演出日期(`events.date`)降序排列。偶活总览 SHALL 过滤掉任何包含 `is_online = 1` 记录的 event(即:只要一个 event 关联了任意一条电切记录,该 event 在总览中整场隐藏,不论是否同时也有现场记录)。每张卡片 SHALL 展示:日期 + 场地(首行)、活动名(第二行)、切奇偶像摘要(第三行,无切奇时显示"(未切奇)")、当场门票价格、当场切奇总价、当场合计价格。卡片内的切奇偶像摘要与当场切奇总价 SHALL 只统计 `is_online = 0` 的记录(在未被过滤掉的 events 中,若有混入电切记录,电切不计入摘要与金额);当场合计价格 SHALL 等于该 event 的 `ticket_price + 现场 records.subtotal 合计`。页面底部 SHALL 显示汇总:总活动数 / 有切奇活动数 / 门票总价 / 切奇总价 / 合计总价。页面 SHALL 支持年份过滤下拉(复用 `year-filter-hide-empty` 规范)。

#### Scenario: 按演出日期降序排列

- **WHEN** `events` 表有日期为 `2026-04-20`、`2026-03-15`、`2025-12-31` 的三条,且均无电切记录
- **THEN** 总览页按此顺序从上到下显示

#### Scenario: 含电切记录的活动整场隐藏

- **WHEN** 某 event `'3rd Anniversary 特典会'` 关联的 records 全部 `is_online = 1`
- **THEN** 总览页 NOT 显示该活动卡片

#### Scenario: 同活动混合现场与电切也整场隐藏

- **WHEN** 某 event 关联 2 条现场记录与 1 条电切记录
- **THEN** 该活动 SHALL 从总览中整场隐藏(按"任一电切则隐藏"规则)

#### Scenario: 纯打卡活动显示未切奇和门票

- **WHEN** 某 `event` 没有任何 `records` 关联,且 `ticket_price = 180`
- **THEN** 该卡片第三行 SHALL 显示"(未切奇)",切奇总价显示"—"或"切 ¥0",门票价格显示 `票 ¥180`,合计价格显示 `合计 ¥180`

#### Scenario: 切奇偶像摘要仅统计现场记录

- **WHEN** 某 `event` 关联的 records 为:小五 ×3 现场 + 桃子 ×2 现场 + 小五 ×1 电切 —— 由于包含电切,该 event 本身会被整场隐藏
- **THEN** 卡片 NOT 渲染

#### Scenario: 全现场活动的切奇偶像摘要与金额格式

- **WHEN** 某 `event` 关联的 records 全部 `is_online = 0`,偶像分布为小五 ×3、桃子 ×2,现场 records 的 `subtotal` 合计为 350,且 `ticket_price = 180`
- **THEN** 卡片第三行 SHALL 显示"小五 ×3 · 桃子 ×2",金额区域 SHALL 显示门票 `¥180`、切奇 `¥350`、合计 `¥530`

#### Scenario: 年份过滤隐藏无活动的年

- **WHEN** 用户展开年份下拉
- **THEN** 下拉仅列出 `events.date` 中存在的年份(外加"全部")

#### Scenario: 底部汇总计数仅统计未被过滤的活动

- **WHEN** 数据库内 15 个 events,其中 3 个含电切记录被隐藏,剩余 12 个中 9 个有现场 records,未隐藏 events 的 `ticket_price` 合计 ¥2,160,现场 records 合计 ¥2,450
- **THEN** 底部 SHALL 显示"12 场 · 9 场有切奇 · 门票 ¥2,160 · 切 ¥2,450 · 合计 ¥4,610"

### Requirement: 活动详情页

系统 SHALL 在偶活总览卡片被点击时打开 `EventDetailPage`,展示活动信息(活动名、场地、日期、门票价格)和该活动关联的所有 `records`,records SHALL 按偶像分组(同一偶像的多条 records 归在一起显示),组内按 `records.created_at` 升序。详情页顶部 SHALL 展示门票价格、切奇总价和合计价格;合计价格 SHALL 等于 `events.ticket_price + records.subtotal 合计`。纯打卡活动 SHALL 显示"暂无切奇记录"的空态提示。详情页 SHALL 提供返回按钮回到总览。

#### Scenario: 有切奇的活动展示分组与金额

- **WHEN** 某活动 `ticket_price = 180`,关联的 records 为:小五 ×3 三条(合计 ¥210) + 桃子 ×2 两条(合计 ¥140)
- **THEN** 详情页 SHALL 分两组显示,每组内列出该偶像的所有 records 条目,顶部 SHALL 显示门票 ¥180、切奇 ¥350、合计 ¥530

#### Scenario: 纯打卡活动空态仍显示门票

- **WHEN** 用户点击"(未切奇)"的活动卡片,该活动 `ticket_price = 180`
- **THEN** 详情页 SHALL 展示活动信息和门票 ¥180、切奇 ¥0、合计 ¥180,records 区域显示"暂无切奇记录"
