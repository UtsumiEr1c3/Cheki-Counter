## MODIFIED Requirements

### Requirement: 添加切奇记录 popup 字段约束

添加切奇记录 popup SHALL 显示偶像名、应援色、团体三个锁定(不可编辑)字段,以及日期、数量、单价、场地四个用户必填字段,以及活动一个可选字段、门票价格一个可选字段和电切一个布尔开关。数量 MUST 为正整数，单价和门票价格 MUST 为非负整数。门票价格字段 SHALL 仅在活动字段非空时参与活动 upsert;留空 SHALL 按 0 处理。popup 提交 SHALL 向 `records` 插入一条新记录,并在同一事务内更新所属偶像的派生汇总;若活动字段有值,同一事务内对 `events` 执行 upsert 并将返回的 `event.id` 写入 `records.event_id`,同时按 events capability 的门票价格补写规则处理 `events.ticket_price`;电切开关状态 SHALL 写入 `records.is_online`。场地字段 SHALL 以"可打字 + 历史下拉"的组合控件形式展示,下拉项 SHALL 来自 `records.venue` UNION `events.venue` 的 DISTINCT 集合,按最近一次使用时间(`records.created_at` 与 `events.created_at` 中该 venue 的最大值)降序排列,用户输入时按子串(case-insensitive)实时过滤下拉项。电切开关 ON 时场地字段 SHALL 被锁定为 `电切` 且禁用编辑。

#### Scenario: 锁定字段不可修改

- **WHEN** 用户从偶像卡片 `+` 打开添加切奇 popup
- **THEN** 偶像名、应援色、团体字段以禁用样式展示,用户无法修改

#### Scenario: 数量必须为正整数

- **WHEN** 用户在 popup 中将数量填写为 0、负数、非数字或空
- **THEN** 系统拒绝提交并在数量字段下方显示错误提示

#### Scenario: 单价允许零元

- **WHEN** 用户在 popup 中填写数量 `2`、单价 `0` 并提交
- **THEN** 系统接受提交并保存 `unit_price = 0`、`subtotal = 0`

#### Scenario: 单价拒绝负数和非整数

- **WHEN** 用户在 popup 中将单价填写为负数、非整数、非数字或空
- **THEN** 系统拒绝提交并在单价字段下方显示错误提示

#### Scenario: 门票价格必须为非负整数

- **WHEN** 用户在 popup 中将门票价格填写为负数或非数字
- **THEN** 系统拒绝提交并在门票价格字段下方显示错误提示

#### Scenario: 门票价格留空按 0 处理

- **WHEN** 用户填写活动字段并将门票价格留空后提交
- **THEN** 系统 SHALL 按门票价格 0 执行活动 upsert

#### Scenario: 未填写活动时门票价格不创建活动

- **WHEN** 用户未填写活动字段,但门票价格填写为 180 并提交
- **THEN** 系统 SHALL 接受提交,`records.event_id` 写入 NULL,且不触碰 `events` 表

#### Scenario: 场地必填

- **WHEN** 用户未填写场地点击提交
- **THEN** 系统拒绝提交并提示"请填写场地"

#### Scenario: 活动字段可选

- **WHEN** 用户未填写活动字段点击提交
- **THEN** 系统接受提交,`records.event_id` 写入 NULL

#### Scenario: 电切开关默认关闭

- **WHEN** 用户首次打开 AddRecordDialog
- **THEN** 电切开关 SHALL 处于 OFF 状态,场地字段可正常编辑

#### Scenario: 电切开关 ON 时场地锁定为"电切"

- **WHEN** 用户将电切开关切换为 ON
- **THEN** 场地字段 SHALL 立即显示 `电切` 且禁用编辑

#### Scenario: 日期默认为今天

- **WHEN** popup 首次打开
- **THEN** 日期字段预填为设备当前日期(YYYY-MM-DD)

#### Scenario: 场地字段聚焦时显示历史下拉

- **WHEN** 用户聚焦场地字段且输入为空(且电切开关 OFF)
- **THEN** 系统显示历史场地下拉列表,来源为 `records.venue` 与 `events.venue` 的并集(DISTINCT),按最近一次使用时间降序排列

#### Scenario: 场地字段按子串过滤

- **WHEN** 用户在场地字段输入 `电切`,且历史中存在 `武汉电切 / 北京电切 / 长沙电切` 以及 `武汉Beach No.11`
- **THEN** 下拉 MUST 只显示 `武汉电切 / 北京电切 / 长沙电切`(包含子串 `电切` 的项),不显示 `武汉Beach No.11`;匹配 MUST 对大小写不敏感

#### Scenario: 场地字段无历史数据时降级为普通输入

- **WHEN** 用户首次使用且 `records` 与 `events` 两表中都无任何 venue 记录
- **THEN** 场地字段行为等同普通文本输入框,不弹出下拉 overlay

#### Scenario: 场地字段允许输入下拉外的新值

- **WHEN** 用户输入 `上海虹馆`,且历史中不存在任何 case-insensitive 匹配的场地
- **THEN** 系统接受该输入,提交后写入 `records.venue = '上海虹馆'`;下次打开 popup 时该场地 MUST 出现在下拉列表里

### Requirement: 活动详情页为已有偶像添加本场切奇记录

系统 SHALL 允许用户从活动详情页选择一个已有偶像, 并为该偶像添加一条归属于当前活动的 cheki record。该路径 SHALL 要求选择偶像并填写数量、单价; 数量 MUST 为正整数，单价 MUST 为非负整数。保存时系统 SHALL 写入 `records.idol_id`、当前活动的 `event_id`、当前活动的 `date`、当前活动的 `venue`、`count`、`unit_price`、`subtotal = count * unit_price`、当前创建时间和 `is_online = 0`。

#### Scenario: 为已有偶像添加本场记录

- **WHEN** 用户在活动详情页选择“已有偶像”, 选中某个已有偶像, 填写数量 `3` 和单价 `70` 后提交
- **THEN** 系统 SHALL 插入一条 records 行, 其中 idol_id 指向所选偶像, event_id 等于当前活动 id, subtotal 等于 `210`

#### Scenario: 已有偶像路径允许零元单价

- **WHEN** 用户在已有偶像路径选择偶像，填写数量 `1` 和单价 `0` 后提交
- **THEN** 系统 SHALL 插入一条 `unit_price = 0`、`subtotal = 0` 的 records 行

#### Scenario: 已有偶像路径必须选择偶像

- **WHEN** 用户在已有偶像路径未选择偶像就提交
- **THEN** 系统 SHALL 拒绝提交并提示用户选择偶像

#### Scenario: 已有偶像路径校验数量和单价

- **WHEN** 用户在已有偶像路径中将数量填写为 0 或将单价填写为负数、非数字或空
- **THEN** 系统 SHALL 拒绝提交并在对应字段显示校验错误

#### Scenario: 活动上下文锁定 event_id 日期和场地

- **WHEN** 用户从活动详情页为已有偶像添加记录
- **THEN** 系统 SHALL 使用当前活动的 event_id、date 和 venue 写入记录, 用户不可在该路径中改为其它活动、日期或场地

#### Scenario: 活动详情添加记录为现场记录

- **WHEN** 用户从活动详情页添加已有偶像或新建偶像的本场记录
- **THEN** 新 records 行的 `is_online` SHALL 为 0, 使该记录计入偶活总览和活动详情的现场切奇统计

## ADDED Requirements

### Requirement: 支出切奇明细查询

系统 SHALL 支持按年份，以及切奇类型或参与方式查询跨偶像、跨活动的切奇明细，并返回导航所需的 `idol_id` 和 `event_id`。

#### Scenario: 按类型和年份查询

- **WHEN** 查询 2026 年主题切明细
- **THEN** 结果 SHALL 只包含 `records.date` 属于 2026 年且 `record_type = theme` 的记录

#### Scenario: 按参与方式和年份查询

- **WHEN** 查询 2026 年电切明细
- **THEN** 结果 SHALL 只包含 `records.date` 属于 2026 年且 `is_online = 1` 的记录

#### Scenario: 零元记录保留在明细中

- **WHEN** 符合筛选条件的记录 `subtotal = 0`
- **THEN** 查询结果 SHALL 包含该记录
