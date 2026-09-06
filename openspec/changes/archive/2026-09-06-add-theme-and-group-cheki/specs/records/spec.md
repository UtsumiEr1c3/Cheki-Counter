## ADDED Requirements

### Requirement: 切奇记录类型
系统 SHALL 为记录保存 `normal`、`theme` 或 `group` 类型。普通切和主题切 MUST 关联偶像；团切 MUST 关联团体名称、成员快照和活动且 `idol_id` 为空。

#### Scenario: 旧记录升级
- **WHEN** 数据库从 v7 升级到 v8
- **THEN** 原有记录的主键、偶像、活动和金额保持不变，类型统一为 `normal`
