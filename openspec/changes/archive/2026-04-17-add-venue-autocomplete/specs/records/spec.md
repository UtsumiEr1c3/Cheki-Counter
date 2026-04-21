## MODIFIED Requirements

### Requirement: 添加切奇记录 popup 字段约束

添加切奇记录 popup SHALL 显示偶像名、应援色、团体三个锁定(不可编辑)字段,以及日期、数量、单价、场地四个用户必填字段。popup 提交 SHALL 向 `records` 插入一条新记录,并在同一事务内更新所属偶像的派生汇总。场地字段 SHALL 以"可打字 + 历史下拉"的组合控件形式展示,下拉项按该场地最近一次使用时间降序排列,用户输入时按子串(case-insensitive)实时过滤下拉项。

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

#### Scenario: 场地字段聚焦时显示历史下拉

- **WHEN** 用户聚焦场地字段且输入为空
- **THEN** 系统显示历史场地下拉列表,按每个场地最近一次使用时间(对应 `records.created_at`)降序排列

#### Scenario: 场地字段按子串过滤

- **WHEN** 用户在场地字段输入 `电切`,且历史中存在 `武汉电切 / 北京电切 / 长沙电切` 以及 `武汉Beach No.11`
- **THEN** 下拉 MUST 只显示 `武汉电切 / 北京电切 / 长沙电切`(包含子串 `电切` 的项),不显示 `武汉Beach No.11`;匹配 MUST 对大小写不敏感

#### Scenario: 场地字段无历史数据时降级为普通输入

- **WHEN** 用户首次使用且 `records` 表中无任何 venue 记录
- **THEN** 场地字段行为等同普通文本输入框,不弹出下拉 overlay

#### Scenario: 场地字段允许输入下拉外的新值

- **WHEN** 用户输入 `上海虹馆`,且历史中不存在任何 case-insensitive 匹配的场地
- **THEN** 系统接受该输入,提交后写入 `records.venue = '上海虹馆'`;下次打开 popup 时该场地 MUST 出现在下拉列表里

### Requirement: 场地字段归一化策略

系统 SHALL 在提交切奇记录前对用户输入的场地字段执行归一化:先 `trim()` 去除首尾空白,再在 `records.venue` 中查找 case-insensitive 相同的已存在字符串;若存在,采用该已存在字符串作为写入值(canonical);若不存在,按 trim 后的原样写入。由此保证同一场地在 DB 中始终只有一个字符串形式,DISTINCT 查询与 CSV 导出不出现"仅大小写不同"的重复项。

#### Scenario: 新场地按原样保存

- **WHEN** 用户输入 `南京无忌演艺空间`,`records` 表中不存在任何 case-insensitive 相同的 venue
- **THEN** 写入的 `records.venue = '南京无忌演艺空间'`(仅 trim)

#### Scenario: 已有场地大小写不同被归一化

- **WHEN** `records` 表中已存在 `venue = 'Beach No.11'` 的记录,用户本次输入 `beach no.11`
- **THEN** 写入的 `records.venue` MUST 等于 `'Beach No.11'`(采用已存在字符串),而不是用户输入的小写形式

#### Scenario: 已有场地大小写完全一致直接保存

- **WHEN** `records` 表中已存在 `venue = '武汉电切'`,用户本次输入 `武汉电切`
- **THEN** 写入的 `records.venue = '武汉电切'`,行为等同无归一化介入

#### Scenario: 空格差异不被视为同一场地

- **WHEN** `records` 表中已存在 `venue = 'Beach No.11'`,用户本次输入 `Beach No. 11`(中间多一个空格)
- **THEN** 归一化 MUST NOT 合并两者,写入的 `records.venue = 'Beach No. 11'`(作为新场地保存)

#### Scenario: CSV 导入不触发归一化

- **WHEN** 用户通过"导入 CSV"合并追加一份数据,文件中包含 `venue = 'beach no.11'` 的行,而 DB 中已有 `venue = 'Beach No.11'`
- **THEN** 导入流程 SHALL 将源 venue 原样写入(遵循 CSV 导入的合并追加语义),NOT 应用手动输入路径的 canonicalization 策略

#### Scenario: 场地字段仅适用于手动录入 popup

- **WHEN** 归一化策略的生效路径
- **THEN** 仅包括 `AddRecordDialog`(对既有偶像加记录)与 `AddIdolDialog`(新建偶像首条记录)两处;其它写入路径(CSV 导入、未来可能的批量操作)不经过本策略
