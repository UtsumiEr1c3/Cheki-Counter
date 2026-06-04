## ADDED Requirements

### Requirement: 活动详情页新建偶像并附带首条本场记录

系统 SHALL 允许用户从活动详情页的新建偶像路径创建全新偶像。该路径 SHALL 要求填写偶像名字、应援色、团体, 以及首条本场切奇记录所需的数量和单价。系统 SHALL 使用当前活动的 `id`、`date` 和 `venue` 创建首条 records 行, 并在同一事务中插入 idols 行和 records 行。系统 MUST 保持 `(名字, 应援色, 团体)` 三元组唯一语义; 若三元组已存在, SHALL 拒绝新建偶像并提示用户改用已有偶像路径添加记录。

#### Scenario: 从活动详情新建偶像成功

- **WHEN** 用户在活动详情页选择“新建偶像”, 填写不存在的 `(名字, 应援色, 团体)` 三元组, 并填写数量和单价
- **THEN** 系统 SHALL 在同一事务中插入一条 idols 行和一条 records 行, 且 records.event_id SHALL 等于当前活动 id

#### Scenario: 新建偶像时活动字段来自当前活动

- **WHEN** 用户从活动详情页进入新建偶像路径
- **THEN** 首条记录的日期和场地 SHALL 使用当前活动的 date 和 venue, 活动关联 SHALL 使用当前活动 id, 用户不可在该路径中改为其它活动

#### Scenario: 新建偶像三元组已存在时拒绝创建

- **WHEN** 用户从活动详情页新建偶像, 但填写的 `(名字, 应援色, 团体)` 与已有偶像完全相同
- **THEN** 系统 MUST NOT 插入新的 idols 行, MUST NOT 插入首条 records 行, 并 SHALL 提示用户改用已有偶像路径添加记录

#### Scenario: 新建偶像仍必须附带首条记录

- **WHEN** 用户从活动详情页新建偶像但未填写数量或单价
- **THEN** 系统 SHALL 拒绝提交并显示校验错误, 不允许产生无 records 的空偶像
