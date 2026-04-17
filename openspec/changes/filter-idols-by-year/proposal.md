## Why

统计页面按年份筛选后，当前年份没有记录的偶像仍然显示在饼图和排行榜中（切数 0、金额 0），干扰阅读。用户希望筛选某一年时只看到该年有实际记录的偶像。

## What Changes

- 当统计页选择了具体年份时，只返回该年有记录的偶像，无记录的偶像不出现在饼图、图例和排行榜中
- 选择"全部"时行为不变，仍显示所有偶像

## Capabilities

### New Capabilities

_无_

### Modified Capabilities

- `year-filter-hide-empty`: 统计页年份筛选时隐藏无记录偶像

## Impact

- `lib/data/idol_repository.dart` — `getAllWithAggregates` 方法的 SQL 查询逻辑需要调整（LEFT JOIN → INNER JOIN when year is set）
- 统计页 UI 无需改动，数据源变化后自然生效
