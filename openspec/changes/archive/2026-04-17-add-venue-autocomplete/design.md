## Context

`records.venue` 目前是一个 `TextFormField`,每次打开添加切奇 popup 都是空白,用户重打字。`counts.csv` 里 67 条记录只有约 25 个不同场地,其中 `武汉电切` 一类重复超过 10 次。键入成本高是一方面,另一方面纯文本易产生大小写/空格等近似重复(典型场景 `Beach No.11` vs `beach no.11`),会污染 DISTINCT 查询、CSV 导出以及未来可能做的"按场地统计"。

当前 `RecordRepository` 已提供 `getDistinctYears`,数据层具备一条 `SELECT DISTINCT ... FROM records` 的前例,新增 `getDistinctVenues()` 与 canonicalization 查询在既有模式下延伸即可。

## Goals / Non-Goals

**Goals:**

- 减少用户手敲 venue 的次数:打开 popup 时能看到历史场地,支持子串过滤
- 防止同一场地因大小写差异在 DB 中重复:case-insensitive 归一化,以首次写入形式为 canonical
- 控件可复用:`AddRecordDialog` 与 `AddIdolDialog` 共用一个 widget
- 零新依赖:用 Flutter 自带 Material 组件

**Non-Goals:**

- 不提供"记忆上次使用的 venue"作为预填默认值(用户明确否决,理由是场地经常变)
- 不清理既有 DB 中因历史原因出现的 case-insensitive 重复 venue(只影响从今往后的写入)
- 不新增"场地管理"页:用户不能重命名 canonical、不能合并已有的重复场地(留待未来变更)
- 不改 CSV 导入语义:导入时保留源数据原样写入,不触发 canonicalization(避免导入行为不可预测)

## Decisions

### D1. 控件选 `Autocomplete<String>` 而非 `DropdownMenu<String>`

Flutter Material 里有两个候选:

| 选项                  | 优点                               | 缺点                                          |
|-----------------------|------------------------------------|-----------------------------------------------|
| `Autocomplete<String>` | 键盘优先,符合"边打边过滤"的流程;API 稳定,Flutter 3.0+ 都可用 | 无原生下拉箭头,空态体验要自定义 |
| `DropdownMenu<String>` | 有现成下拉箭头 + `enableFilter`      | Flutter 3.7+ 才稳定,样式与其它 TextFormField 不一致;空态/free-input 行为较僵 |

**选 `Autocomplete`**:它更接近"增强版输入框"的心智模型,与现有 popup 里的其它 `TextFormField` 视觉一致。空态体验(focus 且输入框为空时显示全量历史)通过 `optionsBuilder` 在输入为空时返回全量列表实现。

### D2. 排序按"最近使用降序"而非"频率降序"或"字母序"

候选:

- **频率降序**:`武汉电切 12 次` 永远在顶部。问题是当用户这周在南京,面对的是一堆无关的武汉场地。
- **最近使用降序** (选):按 `MAX(created_at)` 排序;对巡演式的使用轨迹最贴合——最近几场在哪里,顶部就是哪里。
- **字母/拼音序**:中立但没有利用用户行为信号。

### D3. 匹配算法:子串 (contains),case-insensitive

- 用户输入 `电切` → 匹配 `武汉电切 / 北京电切 / 长沙电切 ...`,这在数据上确实有价值
- 前缀匹配在"XX电切"这种命名结构下几乎无用
- 大小写不敏感 (`LOWER(venue) LIKE '%' || LOWER(input) || '%'`) 与 D4 的归一化保持一致的语义

### D4. Canonicalization 策略:首次写入定 canonical,后续 case-insensitive 相同的输入一律对齐

伪代码:

```
submit(userInput):
  trimmed = userInput.trim()
  match = findVenueCaseInsensitive(trimmed)   # 查 records 表
  canonical = match ?? trimmed
  insert record with venue = canonical
```

候选对比:

- **保存用户原样**:DB 出现"仅大小写不同"的重复 venue,污染 DISTINCT,否决。
- **保存 canonical(本决策)**:DB 同一场地只有一个字符串;用户下次看到下拉里是"统一形式",倾向于点选而不是重打。
- **保存原样 + 下拉去重展示**:UI 掩盖了 DB 的"脏",导出 CSV 会暴露。否决。
- **保存原样 + 批量回填历史为新形式**:副作用大(改写已存在的 record),否决。

**副作用**:若用户第一次不小心敲错了大小写(例如 `beach no.11` 全小写),canonical 就此固化。缓解:因为下拉可见,用户会直接点选;想改 canonical 的话只能"删除该场地的所有记录 + 重新用期望形式录入",属已知限制,不值得为此引入"场地编辑"页。

### D5. canonical 查询下沉到 Repository,不暴露原始 SQL

在 `RecordRepository` 新增两个方法,保持 UI 层不写 SQL:

```dart
Future<List<String>> getDistinctVenues();           // 按最近使用降序
Future<String?> canonicalVenueFor(String input);    // trim + case-insensitive lookup
```

widget 只调用这两个方法,不关心 venue 存在哪张表、怎么排序。

### D6. 复用 widget 放在 `lib/shared/widgets/venue_field.dart`

两处 dialog (`add_record_dialog.dart` / `add_idol_dialog.dart`) 共用。内部封装:

- 接 controller + validator(保持与现有 `TextFormField` 一致的表单集成)
- 初始化时异步加载 `getDistinctVenues()` 填入本地列表
- submit 时由调用方负责走 `canonicalVenueFor`(也可在 widget 内暴露 `resolveCanonical()` helper)

`shared/` 目录此前没有 `widgets/` 子目录,这是首个;预计未来其它复用控件(例如色块选择器)也能落到这里。

### D7. 空列表降级:首次运行 / 无历史数据时等同普通 TextField

`getDistinctVenues()` 返回空时,`Autocomplete.optionsBuilder` 始终返回空,用户体验退化为普通输入框,不弹任何 overlay。无需额外分支逻辑。

## Risks / Trade-offs

**R1. Canonical 被首次错拼固化** → Mitigation: 下拉可见使用户倾向于点选已有形式;同时在 README 的"已知限制"列明"若需更正 venue 拼写,需删除该场地所有记录后重录入"。

**R2. 导入 CSV 绕过归一化** → Mitigation: 文档化"CSV 导入保留源数据原样"(本来也是合并追加语义),与手动输入不同路径;用户若导入了不一致数据,最多只是下拉里多一条选项,不破坏功能。

**R3. 现有 DB 中可能已有 case-insensitive 重复场地(通过 CSV 导入或早期手敲)** → Mitigation: `getDistinctVenues()` 在 UI 层按 `LOWER(venue)` 折叠去重,取每个小写分组里最近使用那一条的原始 venue 字符串;不改写历史记录。

**R4. `Autocomplete` overlay 在小屏/软键盘弹起时可能被遮挡** → Mitigation: Dialog 内使用 `SingleChildScrollView` 已确保键盘弹起时可滚,`Autocomplete` 的 `optionsViewBuilder` 使用默认 Overlay 行为,不需要额外处理。上线后若真出现遮挡再调 `fieldViewBuilder` / `optionsViewBuilder`。

## Migration Plan

无 schema 变更,无需数据迁移。发布即生效。回滚方式 = 恢复 venue 字段为 `TextFormField`,已写入 DB 的数据无兼容性问题。

## Open Questions

无。策略已在前置讨论中确认:最近使用排序、子串匹配、case-insensitive 归一化、canonical = 首次写入形式、不清理历史数据。
