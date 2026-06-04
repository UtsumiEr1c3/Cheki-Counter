## ADDED Requirements

### Requirement: 活动详情页为已有偶像添加本场切奇记录

系统 SHALL 允许用户从活动详情页选择一个已有偶像, 并为该偶像添加一条归属于当前活动的 cheki record。该路径 SHALL 要求选择偶像并填写数量、单价; 数量和单价 MUST 为正整数。保存时系统 SHALL 写入 `records.idol_id`、当前活动的 `event_id`、当前活动的 `date`、当前活动的 `venue`、`count`、`unit_price`、`subtotal = count * unit_price`、当前创建时间和 `is_online = 0`。

#### Scenario: 为已有偶像添加本场记录

- **WHEN** 用户在活动详情页选择“已有偶像”, 选中某个已有偶像, 填写数量 `3` 和单价 `70` 后提交
- **THEN** 系统 SHALL 插入一条 records 行, 其中 idol_id 指向所选偶像, event_id 等于当前活动 id, subtotal 等于 `210`

#### Scenario: 已有偶像路径必须选择偶像

- **WHEN** 用户在已有偶像路径未选择偶像就提交
- **THEN** 系统 SHALL 拒绝提交并提示用户选择偶像

#### Scenario: 已有偶像路径校验数量和单价

- **WHEN** 用户在已有偶像路径中将数量或单价填写为 0、负数、非数字或空
- **THEN** 系统 SHALL 拒绝提交并在对应字段显示校验错误

#### Scenario: 活动上下文锁定 event_id 日期和场地

- **WHEN** 用户从活动详情页为已有偶像添加记录
- **THEN** 系统 SHALL 使用当前活动的 event_id、date 和 venue 写入记录, 用户不可在该路径中改为其它活动、日期或场地

#### Scenario: 活动详情添加记录为现场记录

- **WHEN** 用户从活动详情页添加已有偶像或新建偶像的本场记录
- **THEN** 新 records 行的 `is_online` SHALL 为 0, 使该记录计入偶活总览和活动详情的现场切奇统计
