## MODIFIED Requirements

### Requirement: 偶像存在性由切奇记录派生

系统 SHALL 只保留至少有一条切奇记录的偶像;不允许"有偶像但零记录"的状态。偶像的业务身份由三元组 `(名字, 应援色, 团体)` 唯一确定。新建偶像 popup (`AddIdolDialog`) 的"首条切奇记录"区域 SHALL 与 `AddRecordDialog` 字段齐平,包含日期、数量、单价、场地四个必填项,以及活动一个可选字段、门票价格一个可选字段和电切一个布尔开关。门票价格字段 SHALL 仅在活动字段非空时参与活动 upsert;留空 SHALL 按 0 处理,填写时 MUST 为非负整数。首条记录提交时:若活动字段非空,SHALL 对 `events` 执行 `upsertByTriple(活动名, 场地, 日期, 门票价格)` 并把返回的 `event.id` 写入该首条记录的 `event_id`,同时按 events capability 的门票价格补写规则处理 `events.ticket_price`;电切开关状态 SHALL 写入首条记录的 `is_online`。电切开关 ON 时场地字段 SHALL 被锁定为 canonical `电切` 且禁用编辑,与 `AddRecordDialog` 行为一致。

#### Scenario: 新建偶像必须附带首条记录

- **WHEN** 用户从主界面右下角 `+` 触发新建偶像流程,在 popup 内填写名字、应援色、团体,以及首条切奇的日期、数量、单价、场地
- **THEN** 系统在同一事务内插入一条 `idols` 行和一条 `records` 行,偶像卡片出现在主界面

#### Scenario: 新建偶像 popup 的活动字段可选

- **WHEN** 用户在新建偶像 popup 的"活动(可选)"字段留空
- **THEN** 首条 `records` 行的 `event_id` 写入 NULL,不触碰 `events` 表

#### Scenario: 新建偶像 popup 填入活动名自动关联 event

- **WHEN** 用户在新建偶像 popup 的"活动(可选)"字段选中或输入一个活动名,场地与日期已填(或由活动选项回填),门票价格填 `180`
- **THEN** 系统 SHALL 对 `events` 执行 `upsertByTriple(活动名, 场地, 日期, 门票价格)`;首条 `records` 行的 `event_id` 指向该 event,对应 event 的 `ticket_price` 按 events capability 的补写规则处理

#### Scenario: 新建偶像 popup 选已有活动自动填充门票

- **WHEN** 用户在新建偶像 popup 的活动字段下拉选中 `('VoltFes 2.0', '武汉MAO', '2026-04-20', ticket_price=180)`
- **THEN** 场地字段 SHALL 预填 `'武汉MAO'`,日期字段 SHALL 预填 `'2026-04-20'`,门票价格字段 SHALL 预填 `180`

#### Scenario: 新建偶像 popup 门票价格必须为非负整数

- **WHEN** 用户在新建偶像 popup 将首条切奇区域的门票价格填写为负数或非数字
- **THEN** 系统拒绝提交并在门票价格字段下方显示错误提示

#### Scenario: 新建偶像 popup 电切开关默认关闭

- **WHEN** 用户首次打开新建偶像 popup
- **THEN** 电切开关 SHALL 处于 OFF 状态,场地字段可正常编辑,提交后首条记录 `is_online = 0`

#### Scenario: 新建偶像 popup 电切开关 ON 时场地锁定为"电切"

- **WHEN** 用户将新建偶像 popup 的电切开关切换为 ON
- **THEN** 场地字段 SHALL 立即显示 canonical `电切` 且禁用编辑;即使之后在活动字段选中已有活动,venue 仍保持为 `电切`,不被活动的 venue 覆盖;提交后首条记录 `is_online = 1`

#### Scenario: 删除偶像最后一条记录后偶像消失

- **WHEN** 某偶像只剩一条切奇记录,用户在该偶像详情页删除这条记录
- **THEN** 系统在同一事务内删除该记录并删除对应的 `idols` 行,主界面不再显示该偶像卡片

#### Scenario: 不存在空偶像的入口

- **WHEN** 用户尝试通过任何 UI 路径创建偶像
- **THEN** 系统 MUST 要求同时提供首条切奇记录的完整信息,否则拒绝提交
