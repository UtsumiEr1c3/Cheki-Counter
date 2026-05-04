## Why

偶活总览现在只统计每场切奇花费,但实际出席一场偶活还会产生门票成本。用户想在每个活动场次记录门票价格,并在总览里同时看到门票、切奇、合计三种金额,让活动花费回顾更贴近真实支出。

## What Changes

- 为活动场次增加门票价格字段,每个 `events` 行保存一个非负整数门票价,老数据默认 `0`。
- 在新建活动、添加切奇时创建活动、首条切奇时创建活动的入口中支持填写或带出门票价格。
- 偶活总览卡片显示每场门票价、切奇总价和两者合计;底部汇总显示门票总价、切奇总价和总合计。
- 活动详情页顶部显示该场门票价、切奇总价和合计。
- CSV 导入导出扩展门票价格列,并继续兼容旧列数 CSV。
- 不引入破坏性变更;缺失门票价的历史数据和旧 CSV 按 `0` 处理。

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `events`: 活动实体新增门票价格,偶活总览和活动详情的金额展示规则变化。
- `records`: 添加切奇记录表单在创建/选择活动时同步处理门票价格。
- `idols`: 新建偶像 popup 的首条切奇记录区域在创建/选择活动时同步处理门票价格。
- `csv-io`: CSV 列格式、导入解析和导出内容新增活动门票价格,并保持旧格式兼容。

## Impact

- 数据库: `events` 表新增 `ticket_price INTEGER NOT NULL DEFAULT 0`,数据库版本升级并迁移老数据。
- 数据模型/Repository: `CheckiEvent`, `EventWithSummary`, `EventRepository.upsertByTriple`,活动汇总 SQL 需要携带门票价。
- UI: `AddEventDialog`, `AddRecordDialog`, `AddIdolDialog`, `EventField`, `EventCard`, `EventsOverviewPage`, `EventDetailPage`。
- CSV: `CsvService` header、导入列路由、导出 SQL 与行构造。
- 测试: 覆盖 DB migration、总览汇总、旧 CSV 兼容和导出再导入零增量。
