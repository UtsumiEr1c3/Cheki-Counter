## ADDED Requirements

### Requirement: 特殊切允许零元单价

主题切和活动团切 SHALL 保持数量为正整数，并接受单价为 0 的非负整数。

#### Scenario: 添加零元主题切

- **WHEN** 用户填写完整主题切信息、数量 `1` 和单价 `0` 后提交
- **THEN** 系统 SHALL 保存 `record_type = theme`、`unit_price = 0`、`subtotal = 0` 的记录

#### Scenario: 添加零元团切

- **WHEN** 用户填写完整团切信息、数量 `1` 和单价 `0` 后提交
- **THEN** 系统 SHALL 保存 `record_type = group`、`unit_price = 0`、`subtotal = 0` 的记录
