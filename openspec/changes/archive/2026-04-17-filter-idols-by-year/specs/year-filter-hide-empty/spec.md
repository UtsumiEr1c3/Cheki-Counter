## ADDED Requirements

### Requirement: 年份筛选时隐藏无记录偶像
当统计页选择了具体年份时，`getAllWithAggregates` SHALL 只返回该年份有至少一条记录的偶像。该年份无记录的偶像 MUST NOT 出现在结果列表中。

#### Scenario: 选择具体年份，部分偶像有记录
- **WHEN** 调用 `getAllWithAggregates(year: "2025")`，且偶像 A 在 2025 年有记录、偶像 B 在 2025 年无记录
- **THEN** 返回结果包含偶像 A，不包含偶像 B

#### Scenario: 选择具体年份，所有偶像均无记录
- **WHEN** 调用 `getAllWithAggregates(year: "2020")`，且没有任何偶像在 2020 年有记录
- **THEN** 返回空列表

#### Scenario: 选择"全部"时行为不变
- **WHEN** 调用 `getAllWithAggregates(year: null)`
- **THEN** 返回所有偶像（含聚合值为 0 的偶像，如有）
