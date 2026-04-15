## ADDED Requirements

### Requirement: 添加切奇记录 popup 字段约束

添加切奇记录 popup SHALL 显示偶像名、应援色、团体三个锁定(不可编辑)字段,以及日期、数量、单价、场地四个用户必填字段。popup 提交 SHALL 向 `records` 插入一条新记录,并在同一事务内更新所属偶像的派生汇总。

#### Scenario: 锁定字段不可修改

- **WHEN** 用户从偶像卡片 `+` 打开添加切奇 popup
- **THEN** 偶像名、应援色、团体字段以禁用样式展示,用户无法修改

#### Scenario: 数量与单价必须为正整数

- **WHEN** 用户在 popup 中将数量或单价填写为 0、负数、非数字或空
- **THEN** 系统拒绝提交并在对应字段下方显示错误提示

#### Scenario: 场地必填

- **WHEN** 用户未填写场地点击提交
- **THEN** 系统拒绝提交并提示"请填写场地"

#### Scenario: 日期默认为今天

- **WHEN** popup 首次打开
- **THEN** 日期字段预填为设备当前日期(YYYY-MM-DD)

### Requirement: 单价默认值策略

系统 SHALL 在添加切奇 popup 的单价字段预填默认值:若为已存在偶像,默认值取该偶像按 `created_at` 排序最近一次记录的 `unit_price`;若为全新偶像(通过新建偶像 popup 触发),默认值为 60。

#### Scenario: 已有偶像使用最近单价

- **WHEN** 小五最近一条记录单价为 70,用户从小五卡片的 `+` 打开 popup
- **THEN** 单价字段预填 70

#### Scenario: 新偶像使用 60 作为兜底

- **WHEN** 用户从主界面右下角 `+` 新建偶像
- **THEN** popup 的单价字段预填 60

### Requirement: 小计由数量与单价派生

系统 SHALL 在记录写入时将 `subtotal = count * unit_price` 作为整数持久化到 `records.subtotal`,不在读取时重新计算。

#### Scenario: 写入时计算小计

- **WHEN** 用户提交数量=3、单价=70 的记录
- **THEN** `records` 行的 `subtotal` 字段值为 210

### Requirement: 单条记录删除

系统 SHALL 允许用户在偶像详情页的记录列表中删除任意单条切奇记录。删除 SHALL 在事务中执行,并在删除后检查所属偶像是否还有剩余记录,若无则同时删除 `idols` 行。

#### Scenario: 删除非最后一条记录

- **WHEN** 某偶像有 5 条记录,用户删除其中第 3 条
- **THEN** 该偶像仍保留在主界面,`idols` 行不变,剩余 4 条记录和偶像汇总据此更新

#### Scenario: 删除最后一条记录连带删除偶像

- **WHEN** 某偶像只剩一条记录,用户删除它
- **THEN** `records` 行和 `idols` 行在同一事务中被删除,主界面不再显示该偶像

#### Scenario: 系统不提供批量删除或记录编辑

- **WHEN** 用户在记录列表中长按或多选
- **THEN** 系统 NOT 提供批量删除或就地编辑操作;唯一的修改方式是"删除后重新添加"
