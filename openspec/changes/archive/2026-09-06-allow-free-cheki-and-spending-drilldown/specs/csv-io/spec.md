## ADDED Requirements

### Requirement: CSV 导入接受零元切奇

CSV 导入 SHALL 保持数量为正整数，并将切奇单价 `0` 视为有效的非负整数；负数、非整数和非数字单价仍 SHALL 使该行导入失败。

#### Scenario: 导入零元切奇

- **WHEN** 一条其它字段有效的 CSV 切奇记录数量为 `2`、单价为 `0`
- **THEN** 系统 SHALL 导入该记录并保存 `unit_price = 0`、`subtotal = 0`

#### Scenario: 负数单价仍无效

- **WHEN** CSV 切奇记录的单价为 `-1`
- **THEN** 系统 SHALL 跳过该行并记录单价无效错误
