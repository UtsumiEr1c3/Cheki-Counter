## ADDED Requirements

### Requirement: 记录通过 idol_id 跟随偶像当前资料

系统 SHALL 将 `records.idol_id` 作为切奇记录归属偶像的唯一引用。偶像名字、应援色或团体被编辑后，已有 records 行 SHALL 不修改 `idol_id`，所有通过 JOIN `idols` 展示的记录、详情和统计 SHALL 使用编辑后的偶像当前资料。

#### Scenario: 偶像改名后记录列表显示新名字上下文

- **WHEN** 某偶像有既有 records，用户将该偶像名字从 `小五` 编辑为 `小伍`
- **THEN** 该偶像详情页仍 SHALL 展示原有 records，页面标题和相关偶像资料 SHALL 使用 `小伍`

#### Scenario: 记录去重键不因偶像资料编辑改变

- **WHEN** 用户编辑某偶像的名字、应援色或团体
- **THEN** 该偶像既有 records 的去重键 SHALL 继续使用相同的 `idol_id`，不因展示资料变化而重写 records

#### Scenario: 添加新记录使用编辑后的偶像资料

- **WHEN** 用户编辑偶像团体后，从该偶像入口添加新的切奇记录
- **THEN** 新 records 行的 `idol_id` SHALL 指向同一个偶像，添加弹窗中的锁定字段 SHALL 显示编辑后的当前资料
