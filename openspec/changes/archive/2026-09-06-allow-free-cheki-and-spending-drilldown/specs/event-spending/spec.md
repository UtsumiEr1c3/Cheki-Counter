## ADDED Requirements

### Requirement: 切奇支出下钻

支出页 SHALL 允许用户点击“全部切奇费用”、“普通切”、“主题切”、“团切”、“现场切”和“电切”，打开符合该条目分类及当前年份筛选的切奇明细。累计支出、现场活动门票和现场参加 SHALL 保持为不可点击的汇总项。

#### Scenario: 类型条目下钻

- **WHEN** 用户选择 2026 年并点击“主题切”
- **THEN** 明细页 SHALL 只展示 2026 年的主题切记录

#### Scenario: 参与方式条目下钻

- **WHEN** 用户选择 2026 年并点击“电切”
- **THEN** 明细页 SHALL 只展示 2026 年的电切记录

#### Scenario: 全部切奇下钻

- **WHEN** 用户点击“全部切奇费用”且年份为“全部”
- **THEN** 明细页 SHALL 展示全部切奇记录，包括无活动记录和零元记录

### Requirement: 切奇支出明细展示与导航

切奇支出明细 SHALL 展示每条记录的类型、对象、日期、数量、单价、小计、参与方式和可选活动名。主题切 SHALL 以偶像名作为标题，并在明细信息中展示主题名。有活动关联的记录 SHALL 可进入活动详情；无活动且有关联偶像的记录 SHALL 可进入偶像详情。

#### Scenario: 主题切以偶像名为标题

- **WHEN** 一条主题切记录关联成员“凛”且主题名为“新年主题”
- **THEN** 明细行 SHALL 以“凛”为标题，并显示“主题：新年主题”

#### Scenario: 关联活动的记录进入活动详情

- **WHEN** 用户点击一条 `event_id` 非空的明细
- **THEN** 系统 SHALL 打开对应 `EventDetailPage`

#### Scenario: 无活动记录进入偶像详情

- **WHEN** 用户点击一条 `event_id` 为空且 `idol_id` 非空的明细
- **THEN** 系统 SHALL 打开对应 `IdolDetailPage`

#### Scenario: 零元记录明确显示

- **WHEN** 明细记录的 `subtotal = 0`
- **THEN** 列表 SHALL 显示该记录并将小计显示为 `¥0`
