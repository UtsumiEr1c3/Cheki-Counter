## Why

偶像详情页的折线图在两种情况下几乎不可读：

1. **按日模式稀疏记录变孤立点** —— 记录日期不连续时（如 4/1、4/5、4/10），当前实现按日期 gap>1 拆成独立线段，用户看到的是一地圆点，趋势完全看不出来。
2. **白色/浅色折线隐身** —— 应援色为白色的偶像，折线色 `0xFFFFFFFF` 叠在浅色卡片上基本消失；金/黄/银/薄紫/薄荷绿/藤色等浅色同样低对比。

这两个问题让"切奇随时间的变化"这个详情页的核心价值看不到，优先修。

## What Changes

- 按日折线图改为单条连续折线：不再按日期 gap 拆段，所有记录点按索引顺序直接连起来（X 轴仍只标记有记录的日期，不补零）
- 新增一个"图表安全色"转换：当应援色亮度过高时，自动降亮到可读区间后再用于折线与 `belowBarData`；按日和按月两种模式都套用
- **BREAKING**（相对原 spec）: 按日模式不再保留"稀疏不连接"的语义 —— 原 `statistics` spec 明确写了"不连接缺失区间"，现改为相邻点全连接

## Capabilities

### New Capabilities

_无_

### Modified Capabilities

- `statistics`: 按日折线图的连线语义从"稀疏点之间不连线"改为"所有相邻记录点连线"

## Impact

- `cheki_counter/lib/features/idol_detail/idol_detail_page.dart` — `_buildDailyChart` 去掉 gap 分段逻辑；`_buildDailyChart` 与 `_buildMonthlyChart` 都在传入线色前先过图表安全色
- `cheki_counter/lib/shared/colors.dart` — 新增图表安全色工具函数
- `openspec/changes/add-cheki-counter/specs/statistics/spec.md` — 是 baseline，不改；本 change 在 `specs/statistics/spec.md` 内提交 MODIFIED delta
- 无数据层改动、无 schema 变更、无依赖增减
