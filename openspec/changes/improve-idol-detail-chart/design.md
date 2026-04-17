## Context

偶像详情页（`IdolDetailPage`）用 `fl_chart` 的 `LineChart` 展示切数随时间的变化，提供"按日"和"按月"两种模式。当前实现有两个独立的可读性问题：

1. `_buildDailyChart` 主动做 gap-based 分段：相邻两条记录日期相差 >1 天就把线切成两段 `LineChartBarData`。单点段在 fl_chart 中只渲染圆点，不画线 —— 稀疏记录全是孤立点。这是原 spec（`statistics/spec.md:71`）的显式要求"不连接缺失区间(稀疏)"。
2. 折线色直接取自 `colorFor(idol.fan_color)`。20 种预设色里白色 `0xFFFFFFFF`、金色 `0xFFFFD600`、黄色 `0xFFFDD835`、银色 `0xFFBDBDBD`、薄紫 `0xFFCE93D8`、薄荷绿 `0xFF80CBC4`、藤色 `0xFFB39DDB` 都很浅。而图表背景是 Scaffold 默认白 + `idolColor.withAlpha(25)` 的浅色卡片 —— 浅色线基本消失。

两个问题只影响 idol detail 页渲染，没有跨模块、没有数据层改动、没有新依赖。单文件改动 + 一个共享工具函数即可。

## Goals / Non-Goals

**Goals:**
- 按日折线图的所有相邻记录点用直线连起来，趋势可辨识
- 浅色应援色（白/金/黄/银/薄紫/薄荷绿/藤色等）在折线图上清晰可见
- 改动局限在 UI 层 + shared 工具层，数据层与 spec 的 idol/record 模型不动

**Non-Goals:**
- 不改 X 轴语义：按日模式 X 轴仍是"记录日期索引轴"，不补零、不做时间等比
- 不改按月模式的聚合与 X 轴行为（按月依然生成连续月序列、缺失月补 0）
- 不为图表引入深色模式、不改整体卡片背景色
- 不改 20 种预设色的原始值（`presetColors` 保持不变，只在 chart 渲染时过转换）

## Decisions

**D1: 按日图改为单条连续折线，索引轴不补零**

去掉 `_buildDailyChart` 内的 gap 检测与 `lineBars` 列表，直接用一条 `_makeLineBar(spots, chartColor)`。X 轴 spot 索引仍是 `sortedDays` 的下标，bottom titles 映射逻辑保持不变。

| 候选方案 | 描述 | 优劣 |
|---|---|---|
| A. 单条线 + 索引轴（选定） | 所有记录点按索引顺序连成一条 | X 轴压缩间隙，趋势最直观，改动最小 |
| B. 单条线 + 补零完整日期 | 像 monthly 一样填所有缺失日为 0 | X 轴时间真实，但稀疏记录下会有长平段贴 0 轴，视觉更差 |
| C. 保持分段，仅在单点段渲染大圆点 | 不改线语义 | 还是看不出趋势，没解决问题 |

选 A 的原因：改动最小；和 monthly 的"索引映射 + bottomTitles 查表"风格完全一致；用户在 explore 阶段明确选了 A。

**D2: 图表安全色按亮度阈值降亮**

在 `lib/shared/colors.dart` 加一个 `chartColorFor(Color)` 工具：

```
if (color.computeLuminance() > 0.7):
    hsl = HSLColor.fromColor(color)
    return hsl.withLightness(min(hsl.lightness, 0.45)).toColor()
else:
    return color
```

daily 和 monthly 图进入渲染前都用这个函数过一次。`belowBarData` 也用降亮后的色再 `withAlpha(30)`，保证填充与折线色同源、不出现"线降亮了但底色还浅"的错位。

| 候选方案 | 描述 | 优劣 |
|---|---|---|
| 1. 按亮度自动降亮（选定） | `computeLuminance > 0.7` 的色 HSL lightness clamp 到 ≤ 0.45 | 通用，一处改搞定所有浅色；保留原色相 |
| 2. 给线加深色 shadow | `LineChartBarData.shadow` 加偏移黑阴影 | 保留原色但视觉脏，dot 上也会出阴影 |
| 3. 只替换白色为灰色 | 白→灰、其他原样 | 只修一半，金/黄/银仍低对比 |
| 4. 图表区用深色卡片 | 给 chart 容器换深底 | 浅色在深底清晰，但深色在深底又糟；整体风格也被牵动 |

阈值参数的选择：`0.7` 是 `computeLuminance` (sRGB 相对亮度) 的经验阈值 —— 白色 1.0、金色约 0.78、黄色约 0.84、银色约 0.51、薄紫约 0.46、薄荷绿约 0.51、藤色约 0.41。实测卡片底色 `#FFFFFF + idolColor@10%` 时，亮度 >0.7 的才真正"白底糊白线"。银色、薄紫、薄荷绿、藤色虽浅但仍有足够对比度，不强制降。Lightness 上限 0.45 是 HSL 下"中深色"的分界 —— 白色 → L=0.45 的中灰；金/黄 → L=0.45 的暗金/暗黄，色相保留、对比度足够。

选 1 的原因：用户在 explore 阶段明确选了方案 1；保留偶像色相意义（应援色仍能"看出"是谁的图）；单点阈值、单点 clamp，易解释、易调。

**D3: `chartColorFor` 放在 `lib/shared/colors.dart` 而非 idol detail 内部**

虽然目前只有详情页用，但这是"颜色 → 图表安全色"的纯函数，和 `colorFor` 同族（从"名字/语义 → 展示色"）。放一起未来如果统计页排行榜 legend、团体总览等任何地方要在浅背景上画偶像色也能复用。

## Risks / Trade-offs

**[风险] X 轴非时间等比会误导用户把"稀疏记录"当成"密集记录"** —— 按日模式下 4/1 和 4/30 的两条记录看起来和相邻两天一样近。
→ Mitigation：bottomTitles 仍显示实际日期（`YYYY-MM-DD` 的 `MM-DD` 部分），读数时能看到真实间隔；且这与 monthly 模式的压缩映射风格一致，用户已经适应。

**[风险] 浅色降亮后图表色与卡片色 `idolColor.withAlpha(40)`（AppBar）/ `@25`（Card）色调对不上** —— 线是深化版、背景是原色的浅化版，同框时会略显割裂。
→ Mitigation：仅图表的折线 + `belowBarData` 用降亮色；AppBar、Card 背景等身份识别区保持原应援色。用户视觉上"这是某偶像的页面"的线索来自 AppBar/Card，图表的深线反而不干扰身份辨识。

**[风险] `computeLuminance > 0.7` 阈值选得过严/过松，有色被误伤或漏放过** —— 比如未来新增一个 L=0.68 的应援色，可能也该降亮但没被触发。
→ Mitigation：阈值集中在 `chartColorFor` 一处，后续可按实测调；本 change 以当前 20 种预设色为准验证。

**[风险] 原 spec 的"稀疏不连线"语义被破坏，未来读 baseline spec 的人会困惑** —— baseline 里 `按日模式只画有记录的日期` scenario 明确写了不连线。
→ Mitigation：本 change 在 `specs/statistics/spec.md` 写 MODIFIED delta，用 OpenSpec 归档流程把 baseline 的该 scenario 替换掉；归档后读最新 spec 的人看到的就是新语义。

## Migration Plan

无数据迁移、无 schema 变更。改动合入后：

1. 用户下次打开详情页即得新渲染（Flutter 热重载友好）
2. 已安装版本的数据库与 CSV 格式完全兼容
3. 无回滚担忧 —— 纯 UI 层回退只需还原两处源文件
