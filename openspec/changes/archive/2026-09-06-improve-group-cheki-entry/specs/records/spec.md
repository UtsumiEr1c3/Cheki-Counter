## MODIFIED Requirements

### Requirement: 切奇记录类型

系统 SHALL 为记录保存 `normal`、`theme` 或 `group` 类型。普通切和主题切 MUST 关联偶像；团切 MUST 通过团体关联保存一个或多个参与团体、保存成员快照和活动且 `idol_id` 为空。一条团切无论关联多少团体都 MUST 只对应一条记录。

#### Scenario: 旧记录升级

- **WHEN** 数据库从 v7 升级到 v8
- **THEN** 原有记录的主键、偶像、活动和金额保持不变，类型统一为 `normal`

#### Scenario: 单团体数据迁移

- **WHEN** 数据库从 v9 升级到 v10
- **THEN** 每条已有团切的 `group_name` SHALL 转换为该记录唯一且位置为 0 的团体关联，原记录数据保持不变

#### Scenario: 联合团切原子写入

- **WHEN** 系统保存包含多个团体的团切
- **THEN** 团切主体和全部团体关联 MUST 在同一事务内成功或共同回滚
