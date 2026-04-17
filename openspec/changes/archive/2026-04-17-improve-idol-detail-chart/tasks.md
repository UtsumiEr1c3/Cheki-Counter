## 1. Shared 层 - 图表安全色

- [x] 1.1 在 `cheki_counter/lib/shared/colors.dart` 新增 `chartColorFor(Color color)` 函数：当 `color.computeLuminance() > 0.7` 时，用 `HSLColor.fromColor(color).withLightness(min(hsl.lightness, 0.45)).toColor()` 返回降亮后的色；否则原样返回
- [x] 1.2 在 `colors.dart` 顶部 `import 'dart:math'` 以便使用 `min`（若未导入）

## 2. UI 层 - 详情页折线图

- [x] 2.1 修改 `cheki_counter/lib/features/idol_detail/idol_detail_page.dart` 的 `_buildDailyChart`：删除第 183-201 行的 gap 分段逻辑（`lineBars` 列表、`currentSegment` 循环、按 `gap > 1` 拆段），改为单条 `LineChartBarData`，即 `lineBarsData: [_makeLineBar(spots, chartColor)]`
- [x] 2.2 在 `_buildDailyChart` 与 `_buildMonthlyChart` 内，在调用 `_makeLineBar` 前把传入的 `lineColor` 过一遍 `chartColorFor`，得到 `chartColor`；两处都用 `chartColor` 替代原 `lineColor` 作为 `_makeLineBar` 的第二个参数
- [x] 2.3 确认 `_makeLineBar` 内的 `belowBarData` 使用的是传入的 `color`（即已经是降亮版），不需要额外改动；若不是，同步改为用降亮色

## 3. 验证

- [x] 3.1 在 `cheki_counter/` 目录下运行 `flutter analyze`，确认无静态错误或新增 warning
- [x] 3.2 在设备/模拟器上手动验证：选一个白色应援色偶像进详情页，确认按日和按月图的折线都清晰可见（非纯白）
- [x] 3.3 在设备/模拟器上手动验证：选一个记录稀疏的偶像（同月内日期有跳跃）进详情页，切到按日模式，确认所有相邻点用直线连成一条连续折线
- [x] 3.4 在设备/模拟器上手动验证：选一个深色应援色偶像（如红色/蓝色）进详情页，确认折线色仍为原应援色、未被降亮
