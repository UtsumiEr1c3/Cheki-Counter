## Why

当前添加切奇记录时,"场地"字段每次都是空白输入,用户需要从头手敲,而 `counts.csv` 的实际使用模式显示 venue 高度重复(例如"武汉电切"出现 12+ 次,"北京电切""长沙电切"等电切类场地也频繁出现)。纯文本输入还容易产生大小写不一致的脏数据(`Beach No.11` vs `beach no.11`),会让 DISTINCT 场地统计、CSV 导出出现"几乎一样但算两条"的冗余。

## What Changes

- 场地字段由纯文本输入改为"可打字 + 历史下拉"的组合控件:聚焦时显示历史场地列表,打字时按**子串**实时过滤,按**最近使用时间降序**排序
- 允许输入下拉列表里不存在的新场地,提交后自然进入下次的历史来源
- 提交时进行 trim 和**大小写归一化**:若新输入的 venue 与历史某条 venue 仅大小写不同,则采用该历史 venue 的原文作为保存值,使 DB 里同一场地始终只有一个 canonical 形式
- 历史数据不做主动清理:既有的大小写重复场地保持原样,只确保从今往后写入的场地遵循新规则
- 同一个控件应用在"添加切奇记录" popup (对既有偶像加记录) 和"新建偶像" popup (首条记录) 两处

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `records`: 添加切奇记录 popup 的"场地"字段行为扩展——支持历史下拉建议、子串过滤、最近使用排序,以及提交时的 case-insensitive 归一化策略

## Impact

- **代码**:
  - `lib/data/record_repository.dart`:新增 `getDistinctVenues()` 与 `canonicalVenueFor(String input)` 方法
  - `lib/features/home/add_record_dialog.dart` 与 `lib/features/home/add_idol_dialog.dart`:venue 字段替换为新控件,提交路径经过 canonicalization
  - 可能新增 `lib/shared/widgets/venue_field.dart`(或类似命名)作为复用控件
- **数据**:无 schema 变更,`records.venue` 列类型与约束不变
- **依赖**:无新增,继续使用 Flutter Material 自带 `Autocomplete` / `DropdownMenu`
- **用户可见行为**:venue 不再提供"默认值 / 记忆上次"功能(因为场地经常变),仅提供"历史可选"的辅助输入
