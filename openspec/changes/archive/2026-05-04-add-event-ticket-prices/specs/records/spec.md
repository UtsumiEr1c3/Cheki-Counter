## MODIFIED Requirements

### Requirement: 添加切奇记录 popup 字段约束

添加切奇记录 popup SHALL 显示偶像名、应援色、团体三个锁定(不可编辑)字段,以及日期、数量、单价、场地四个用户必填字段,以及活动一个可选字段、门票价格一个可选字段和电切一个布尔开关。门票价格字段 SHALL 仅在活动字段非空时参与活动 upsert;留空 SHALL 按 0 处理,填写时 MUST 为非负整数。popup 提交 SHALL 向 `records` 插入一条新记录,并在同一事务内更新所属偶像的派生汇总;若活动字段有值,同一事务内对 `events` 执行 upsert 并将返回的 `event.id` 写入 `records.event_id`,同时按 events capability 的门票价格补写规则处理 `events.ticket_price`;电切开关状态 SHALL 写入 `records.is_online`。场地字段 SHALL 以"可打字 + 历史下拉"的组合控件形式展示,下拉项 SHALL 来自 `records.venue` UNION `events.venue` 的 DISTINCT 集合,按最近一次使用时间(`records.created_at` 与 `events.created_at` 中该 venue 的最大值)降序排列,用户输入时按子串(case-insensitive)实时过滤下拉项。电切开关 ON 时场地字段 SHALL 被锁定为 `电切` 且禁用编辑。

#### Scenario: 锁定字段不可修改

- **WHEN** 用户从偶像卡片 `+` 打开添加切奇 popup
- **THEN** 偶像名、应援色、团体字段以禁用样式展示,用户无法修改

#### Scenario: 数量与单价必须为正整数

- **WHEN** 用户在 popup 中将数量或单价填写为 0、负数、非数字或空
- **THEN** 系统拒绝提交并在对应字段下方显示错误提示

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

### Requirement: AddRecordDialog 活动字段

系统 SHALL 在添加切奇 popup 中新增"活动"字段,字段位置位于场地字段之后、是可选字段(留空允许提交)。字段 SHALL 采用"可打字 + 历史下拉"控件:下拉项来自 `events` 表,按 `(name)` 子串过滤(大小写不敏感),按 `events.created_at` 降序。用户可以:(a) 从下拉选已有 event,(b) 输入全新活动名提交(同步 upsert event)。若用户选了已有 event,场地、日期与门票价格字段 SHALL 自动填充为该 event 的 venue、date 与 ticket_price(用户仍可修改;若修改后与已选 event 不一致,提交时以表单字段为准并 upsert 为新 event 或复用同三元组 event)。若用户输入了活动名但未填场地或日期,提交时以表单当前场地和日期字段的值作为 event 的 venue 和 date。若用户输入了活动名但未填门票价格,提交时 SHALL 以 0 作为本次 upsert 的门票价格。

#### Scenario: 字段可选,空提交走 legacy 路径

- **WHEN** 用户打开 AddRecordDialog,填完其它必填项,活动字段留空,点击提交
- **THEN** 记录正常写入,`event_id = NULL`

#### Scenario: 选已有活动自动填充场地日期与门票

- **WHEN** 用户在活动字段下拉选中 `('VoltFes 2.0', '武汉MAO', '2026-04-20', ticket_price=180)`
- **THEN** 场地字段 SHALL 预填 `'武汉MAO'`,日期字段 SHALL 预填 `'2026-04-20'`,门票价格字段 SHALL 预填 `180`

#### Scenario: 输入新活动名同步 upsert

- **WHEN** 用户在活动字段输入 `'定期公演'`(`events` 中不存在该三元组)且场地填 `'武汉电切'`、日期填 `'2026-04-21'`、门票价格填 `120`,提交
- **THEN** 系统先 INSERT `events('定期公演', '武汉电切', '2026-04-21', ticket_price=120)`,取回 `event.id`,再 INSERT `records` 并挂 `event_id = event.id`(同一事务)

#### Scenario: 输入已存在三元组复用

- **WHEN** 用户输入的活动名、场地、日期组成的三元组已在 `events` 存在
- **THEN** 系统 NOT 新增 event,直接复用已有 `event.id`,并按 events capability 的门票价格补写规则处理 `ticket_price`
