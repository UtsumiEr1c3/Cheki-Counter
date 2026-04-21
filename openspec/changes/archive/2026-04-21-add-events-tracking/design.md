## Context

当前模型以 `idols` + `records` 双表为中心,"去现场"只能靠切奇记录间接表达 —— 没切偶像的场合无处可录。同时场地字段仅存在于 `records.venue`,同一场活动的多条切奇依赖字符串一致性才不散架。用户希望把"活动(偶活)"提升为一等实体,既承载"去了没切"的打卡,也统一挂载同场活动的多条切奇。

约束:
- 离线单机 SQLite,无后端,不追求强一致跨表约束(SQLite 的 FOREIGN KEY 默认不强制)。
- 70+ 条历史记录和相应 CSV 备份已存在,用户在意"老数据零迁移"。
- CSV 是唯一的备份与跨设备迁移手段,格式改动需要向后兼容 legacy 9 列。
- 用户明确:同一天同一场地可以有多场活动(昼/夜公演),所以 event 必须是独立实体。

## Goals / Non-Goals

**Goals:**
- 活动作为一等公民:可单独创建(纯打卡),可与 0..N 条 records 关联。
- 老数据零迁移:已有 records 保持 `event_id = NULL`,显示与编辑路径继续工作。
- 单个 CSV 文件承载三类行(有活动切奇 / legacy 切奇 / 纯打卡),读写对称。
- 偶活总览页用演出日期驱动时间线,纯打卡行也在列表里。
- 偶像卡 `+` 的现有流程不被复杂化:活动字段可选,默认可以不填。

**Non-Goals:**
- 不做"把老 records 按 (venue, date) 聚类回填成 events"的批量补录工具。
- 不做活动的编辑/删除 UI(后续 change)。
- 不改 AddIdolDialog —— 新建偶像首条切奇走 legacy 路径,不强制选活动。
- 不对 `idols` 表结构做任何更改。
- 不引入 ORM、迁移框架或跨表事务约束强化。

## Decisions

### D1. Events 独立建表 + records 加可空 `event_id`

选用: `events(id, name, venue, date, created_at)` + `UNIQUE(name, venue, date)`;`records` 加 `event_id INTEGER NULL`。

**为什么**:
- 可空 FK 让老数据保持原样,无需回填;legacy 切奇就是 `event_id = NULL` 的 records。
- 活动身份必须独立于 (venue, date):昼/夜公演场景要求第三维(name)参与唯一性。

**候选对比**:
- (a) 在 records 上直接加 event name 列 → 否。纯打卡活动无 records 可依,无法表达。
- (b) records 强制 event_id NOT NULL,老数据合成假 event 回填 → 否。老数据迁移量大,且用户明确拒绝批量补录。
- (c) 双 CSV 文件(events.csv + records.csv) → 否。UX 多一步,分享备份不便携。

### D2. Venue 真相搬到 `events`,`records.venue` 降级为 legacy

选用: 新数据路径 venue 写到 `events.venue`;`records.venue` 不删除,但仅在 `event_id IS NULL` 的老数据上有语义。显示层使用 `event?.venue ?? record.venue` fallback。场地历史下拉来源短期内 UNION 两表。

**为什么**:
- 一场活动对应唯一场地是现实不变量,放在 events 上避免同活动多 records 场地拼写漂移。
- 不清理 `records.venue` 是因为老数据上它是唯一的 venue 真相,删了就丢了。

**候选对比**:
- (a) 只在 records 上保留 venue,events 不存 venue → 否。纯打卡活动(无 records)就没地方放场地了。
- (b) 强行把老 records.venue 迁移到合成 events 上 → 否。等于 D1 的 (b),违反老数据零迁移原则。

### D3. Records 去重 key 升级加入 `event_id`

选用: 去重 key 从 `(idol_id, date, count, unit_price, venue, created_at)` 扩为 `(idol_id, date, count, unit_price, venue, created_at, event_id)`。`NULL event_id` 参与等值判定(NULL = NULL 视为相等,需用 `IS` 比较而非 `=`)。

**为什么**: 同一天同场地同偶像的昼/夜公演各切一次,应该是两条独立 records —— 去重 key 不升级会被合并成一条。

**候选对比**: 直接去掉 `created_at`(用户早先提过)→ 否。去掉会让"同日同场地同偶像多次切奇"这种极罕见但真实场景无法区分;用户后来也改口保留 created_at。

### D4. CSV 单文件 11 列,追加在尾部

选用: 新列顺序 `偶像名, 应援色, 团体, 日期, 数量, 单价, 小计, 场地, 创建时间, 活动名, 活动场地, 活动日期`。三类行:

```
A (有活动有切奇) : 全部 11 列非空(除极个别业务允许空)
B (legacy 切奇)  : 活动 3 列空,前 9 列同今日格式
C (纯打卡)       : 偶像/切奇 6 列(索引 0-5)空,小计/场地空,创建时间非空,活动 3 列非空
```

**为什么**: 追加比插入改动小、对老 CSV 导入零破坏;空格允许表达三类行无需辅助标记列;创建时间留在第 9 列让一行始终只有一个 created_at。

**候选对比**:
- (a) 插入活动列到 records 之间 → 否。破坏老 CSV 的列位置,导入路径要双路解析。
- (b) 双文件 zip → 否,D1 已否决。
- (c) 加一个"行类型"标记列 → 否。冗余,三类行可通过字段空与非空推断。

### D5. 导出排序改为 `COALESCE(events.date, records.date) DESC`

选用: 最外层 `ORDER BY COALESCE(e.date, r.date) DESC, r.id ASC`(tie-break 保稳)。对 legacy 9 列 CSV 的导出也适用(legacy 行 `e.date` 为 NULL,直接 fallback 到 `r.date`)。

**为什么**: 用户看 CSV 的心智是"我的演出时间线",而不是"我录入的操作时间线"。创建时间排序让同批次批量录入的老数据挤在一起,没信息量。

**候选对比**: 保留 `created_at DESC` → 否,已被用户明确否决。

### D6. 导入三行路径 + event upsert

选用: 单行解析分三路:

```
if (活动名, 活动场地, 活动日期) 全非空 → events upsert (键 UNIQUE(name, venue, date))
                                     取回 event.id

if (偶像名, 应援色, 团体, 数量, 单价, 场地) 全非空 → records insert,
    若上一步 event 存在则 records.event_id = event.id

if 两侧都空 → 报错
```

Upsert 采用"先 SELECT 找再 INSERT"(SQLite `ON CONFLICT ... DO UPDATE` 也可,但 `events` 除 created_at 外无其它可更新字段,复杂度不值)。

**为什么**: 单行可能既有活动又有 records(A 行),也可能只有一侧(B/C 行)。把两侧解析解耦让三类行通过同一个入口处理。

### D7. DB 版本升级 v1 → v2,`onUpgrade` 增量迁移

选用: `sqflite` 的 `version: 2`,在 `onUpgrade(db, oldV, newV)` 里:

```sql
CREATE TABLE events (...);
CREATE UNIQUE INDEX idx_events_triple ON events(name, venue, date);
ALTER TABLE records ADD COLUMN event_id INTEGER;
```

不建 FK 约束(SQLite 默认不执行),仅靠应用层保证引用完整性。

**为什么**: 已有 70+ 条 records 不能丢;`ALTER TABLE ADD COLUMN` 是 SQLite 支持的少数非破坏性 schema 变更之一。不建 FK 是因为 SQLite 默认 `PRAGMA foreign_keys = OFF`,开启需每连接设置,收益不足成本。

### D8. UI 入口:顶层 `+` 改菜单,活动总览在统计旁

选用:
- `home_page.dart` 右下 FAB 变成 `SpeedDial`(或简化版 PopupMenu):两个子项 "新建偶像" / "新建活动"。
- "新建活动" 打开 `AddEventDialog`(纯打卡,三字段:name + venue + date)。
- `AddRecordDialog` 新增 "活动" 字段,UI 类似 venue 的"可打字 + 历史下拉"模式,下拉项来自现有 `events`,匹配 `name` 子串;用户可输入新活动名;提交时 `venue` 与 `date` 若用户选了已有 event 就从该 event 推导,否则用用户当前填写的值去 upsert。
- AppBar 右上角统计图标旁加一个 `event` 图标,点击进 `EventsOverviewPage`。

**为什么**: 用户明确反对在 AddRecordDialog 上加"只看演出不特典"开关;顶层入口分流更清晰。偶活总览放 AppBar 按钮而不是底 Tab,是因为当前没有 Tab 容器,引入 BottomNavigationBar 成本过高。

### D9. 偶活总览页信息密度

选用: `ListView`,卡片纵向堆叠:

```
┌─ 偶活 ───────────────── 2026 ▾ ─┐
│ 2026-04-20 · 武汉电切            │
│ VoltFes 2.0                      │
│ 小五 ×3 · 桃子 ×2      ¥350      │
│ ──────                           │
│ 2026-03-15 · 北京电切            │
│ 定期公演                         │
│ (未切奇)                         │
└─────────────────────────────────┘
合计: 12 场 · 9 场有切奇 · ¥2,450
```

年份下拉复用 `year-filter-hide-empty` 模式。点卡片进详情页,按偶像分组展示当场 records。

## Risks / Trade-offs

- **[风险] CSV 往返语义模糊**: 用户导出 11 列后手工删了活动 3 列又导入 → 等于把 A 行降级为 B 行,event 丢失。
  → Mitigation: 导入摘要里明确区分 "新增活动 N / 新增切奇 M / 跳过重复 K";用户自行把控。不在代码里做"检测降级"的智能判断。

- **[风险] 去重 key 包含 `event_id` 后,NULL 比较需用 `IS` 而非 `=`**: SQLite 的标准 `=` 对 NULL 返回 NULL 不返回 true,会漏判导致重复插入。
  → Mitigation: `RecordRepository.existsByDedupKey` 的 WHERE 子句针对 `event_id` 单独用 `(event_id IS NULL AND ?1 IS NULL) OR event_id = ?1`,并在 RecordRepository 测试(若有)里加针对性 case。

- **[风险] Venue 历史下拉 UNION 两表会出现"老 records 的场地仅大小写不同但没被 events 继承规范化"的条目**: 用户看到两条几乎一样的选项。
  → Mitigation: 查询语句里 `DISTINCT venue` 就近处理;长期靠用户自然使用让 events 路径逐渐成为主流,短期接受观感瑕疵。

- **[风险] Events 无编辑/删除 UI,用户新建活动时打错字无法修复**: 只能通过"再建一个、老的闲置"绕。
  → Mitigation: 文档上承认为本 change 的已知限制,后续 change 补编辑。AddEventDialog 提交前显示 summary 让用户二次确认。

- **[Trade-off] Events 不挂 idol_id / 不强制 at-least-one-record**: 纯打卡活动可以永远没有 records。设计上接受"孤立 event"的存在,不像 idols 那样需要"有记录才存在"的派生语义。
  → 代价: 数据库里可能堆积无切奇活动,不会自动清理。接受,因为这些就是用户明确想要记录的"去了但没切"的场次。

- **[Trade-off] AddRecordDialog 增加 event 字段后表单更长**: 用户填写链路变长。
  → 字段放在 venue 之后、作为可选,默认空;不填则按 legacy 路径(event_id = NULL)提交,不影响老用户肌肉记忆。
