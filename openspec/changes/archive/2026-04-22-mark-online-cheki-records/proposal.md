## Why

偶活总览页目前会显示所有 `events` 行,而用户把"电切"(电话/远程拿切,没去现场)也记为了一条带 `event_id` 的切奇 —— 这导致"去过的活动"和"只是线上留了切的活动"混在一起,无法只看"真正出席过的场次"。依赖 `venue = '电切'` 字符串约定过滤不够严格(大小写、变体、手滑都会漏),也没法把"电切还是现场"当成数据层事实写清楚。

同时偶像详情页的记录列表只显示场地,看不到活动名。用户想回顾"这场切是哪场 LIVE 留的"时得点进事件总览反推,信息链不完整。

## What Changes

### 核心:加电切标记

- `records` 表新增 `is_online INTEGER NOT NULL DEFAULT 0` 列(0=现场、1=电切),DB v2 → v3
- `AddRecordDialog` 首行新增"电切"开关;打开时场地字段自动填 `电切` 并锁定,关闭时解锁
- `AddIdolDialog` "首条切奇记录"区域同步新增"电切"开关,行为与 `AddRecordDialog` 一致;并补齐"活动(可选)"字段,选中已有活动时自动回填场地/日期,提交时 upsert event 并把 `event_id` 写入首条记录
- 偶活总览查询过滤:任何含 `is_online = 1` 记录的 event 从总览中整场隐藏(按活动粒度过滤)
- 去重键扩展为 `(idol_id, date, count, unit_price, venue, created_at, event_id, is_online)`,防止把"同日同场同偶像的现场 +电切"错误合并
- 迁移回填:DB 升级时对 `venue = '电切'` 的历史记录自动 `is_online = 1`(case-insensitive,覆盖"电切"/"電切"等变体)

### 附带:偶像详情列表显示活动名

- `RecordRepository.listByIdol` 改为 LEFT JOIN `events`,返回活动名
- 详情页 `ListTile` 拆成两行 subtitle:第一行活动名(有关联 event 才显示),第二行 `场地 · 单价¥N`

### CSV:加一列

- 列从 12 扩到 13,尾部追加 `电切`(值为 `0`/`1`)
- 向后兼容:读 12 列/11 列/9 列老文件时,缺的 `电切` 列按 `0` 处理(均视为现场)

### 不在本次范围内

- 统计页对电切的分别聚合(月度花费等继续合并计算,后续可开独立提案)
- 电切的单独 tab 或筛选浏览
- "编辑记录"入口(电切误标后仍走"删除重建"路径)

## Capabilities

### Modified Capabilities

- `records`: 新增 `is_online` 字段与录入 UI 开关、去重键扩展、场地/电切联动策略、详情页活动名显示
- `idols`: `AddIdolDialog` "首条切奇记录"区域补齐电切开关与活动字段,与 `AddRecordDialog` 字段齐平
- `events`: 偶活总览过滤规则增加"含电切记录的活动整场隐藏"
- `csv-io`: 13 列格式 + 对 9/11/12 列老文件的缺列默认规则

## Impact

- **DB schema**: `cheki_counter.db` v2 → v3。`onUpgrade(2→3)`:`ALTER TABLE records ADD COLUMN is_online INTEGER NOT NULL DEFAULT 0` + `UPDATE records SET is_online = 1 WHERE LOWER(venue) LIKE '%电切%' OR LOWER(venue) LIKE '%電切%'`
- **data 层**:
  - `CheckiRecord` 新增 `isOnline` 字段(bool,读写时与 INTEGER 0/1 互转)
  - `RecordRepository.insert` 接受 `isOnline`;`existsByDedupKey` 参数加 `isOnline`;`listByIdol` 返回结构扩展携带活动名(可空)
  - `EventRepository.getAllWithRecordsSummary` SQL 加 `WHERE NOT EXISTS (SELECT 1 FROM records WHERE event_id = e.id AND is_online = 1)` 子句
- **features 层**:
  - `AddRecordDialog` 增加"电切"开关与场地字段联动
  - `IdolDetailPage` 记录 `ListTile` subtitle 改两行,复用同一 build 方法
- **CSV 服务**: `_header` 13 列;`exportCsv` 多输出一列;`importCsv` 列数路由逻辑加 13 分支,其余分支 `is_online` 默认 0
- **specs**: `records`、`events`、`csv-io` 三个 capability 均有 delta
- **兼容性**: 老 12/11/9 列 CSV 可无损导入;新版导出的 13 列 CSV 在老版导入会被列数检查拒绝(用户需先升级)
