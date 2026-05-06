## Why

团体总览目前只能看到每个团体的全量合计数据,无法按年份查看阶段性的团体排行,也无法继续下钻查看这个团体里具体切过哪些小偶像。增加年份筛选和团体详情能让用户先从"团体维度"看某年分布,再自然追到"小偶像维度"。

## What Changes

- 团体总览列表中的每个团体项可点击。
- 团体总览页提供年份筛选,选项包含"全部"和数据中实际出现过的年份。
- 团体总览页的团体切数、金额和偶像数量随当前年份筛选刷新。
- 点击团体后进入团体详情页,展示该团体的汇总数据和该团体名下切过的小偶像列表。
- 团体详情页继承团体总览页当前选择的年份,并继续提供年份筛选。
- 团体详情页提供"按切数 / 按金额"切换,小偶像列表随当前排序模式和年份筛选刷新。
- 团体详情页的小偶像行可点击进入现有小偶像详情页。

## Capabilities

### New Capabilities

- None

### Modified Capabilities

- `statistics`: 扩展团体总览需求,新增总览年份筛选、团体点击下钻、团体详情页、年份继承和团体内小偶像排序行为。

## Impact

- `cheki_counter/lib/features/statistics/group_overview_page.dart`: 为团体总览增加年份筛选,并为团体项增加点击入口。
- `cheki_counter/lib/features/statistics/`: 新增或扩展团体详情页面 UI。
- `cheki_counter/lib/data/idol_repository.dart`: 扩展团体聚合查询支持年份筛选;新增按团体、年份和排序模式查询小偶像聚合数据的方法。
- `cheki_counter/lib/data/record_repository.dart`: 可复用现有年份查询能力。
- `cheki_counter/lib/app.dart`: 如采用命名路由,需要注册团体详情页路由;也可使用 `MaterialPageRoute` 局部导航。
- 测试需要覆盖团体总览年份筛选、团体详情数据聚合、年份继承、排序切换和小偶像详情跳转入口。
