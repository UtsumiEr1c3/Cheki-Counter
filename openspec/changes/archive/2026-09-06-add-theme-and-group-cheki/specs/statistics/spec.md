## ADDED Requirements

### Requirement: 团切统计归属
个人统计 SHALL 排除团切；团体统计 SHALL 将该团成员的普通切和主题切与 `group_name` 相同的团切合并，团切只累计一次。

#### Scenario: 团体金额包含团切
- **WHEN** 团内成员个人切合计 ¥500，团切合计 ¥200
- **THEN** 团体统计显示 ¥700，成员个人统计合计仍为 ¥500
