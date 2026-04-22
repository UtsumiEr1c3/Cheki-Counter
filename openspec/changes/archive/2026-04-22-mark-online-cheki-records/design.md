# 设计说明

## 为什么选加字段,而不是复用 `venue = '电切'`

两条路径对比:

| 维度 | α: 加 `is_online` 字段 | β: 依赖 `venue = '电切'` 字符串 |
|------|----------------------|--------------------------------|
| 数据可靠性 | 强(布尔) | 弱(受大小写、"电切"/"電切"、空格变体影响) |
| 过滤实现 | `WHERE is_online = 1` | `WHERE venue LIKE '%电切%'`(脆弱) |
| CSV 往返 | 多一列但语义清晰 | 零改动但场地字段承载双重语义(位置+电切标记) |
| 迁移成本 | DB v3 + 一次 UPDATE 回填 | 零 |
| 未来可扩展 | 可加 `is_online` 派生的统计维度 | 难,得回头补字段 |

用户明确表达"希望有个电切的标记",选 α。β 的零改动优势在数据量大或改动开销特别敏感时才值得,这里不成立。

## 为什么过滤用 NOT EXISTS 而不是 LEFT JOIN + GROUP BY HAVING

偶活总览当前 SQL:

```sql
SELECT e.*, SUM(r.count), SUM(r.subtotal), COUNT(r.id)
FROM events e
LEFT JOIN records r ON r.event_id = e.id
GROUP BY e.id
```

候选 A(NOT EXISTS 子查询):

```sql
SELECT ...
FROM events e
LEFT JOIN records r ON r.event_id = e.id
WHERE NOT EXISTS (
  SELECT 1 FROM records WHERE event_id = e.id AND is_online = 1
)
GROUP BY e.id
```

候选 B(HAVING 聚合):

```sql
SELECT ..., SUM(r.is_online) AS online_count
FROM events e
LEFT JOIN records r ON r.event_id = e.id
GROUP BY e.id
HAVING online_count = 0 OR online_count IS NULL
```

选 A,理由:
- 语义直观 —— "存在任一电切记录则整场隐藏"直接对应 NOT EXISTS
- 聚合字段(SUM/COUNT)只算现场数据时,B 需要额外 `SUM(CASE WHEN is_online=0 THEN ...) `;A 配合 `r.is_online = 0` 子句更简洁。
- 实际取数据时应同时在 JOIN 条件或 WHERE 里加 `r.is_online = 0`,避免混进电切的 count/amount —— 这点 A/B 一样,但 A 的外层 WHERE 跟 JOIN 子句语义分得更开。

最终 SQL 会是:

```sql
SELECT e.*,
       COALESCE(SUM(r.count), 0) AS total_count,
       COALESCE(SUM(r.subtotal), 0) AS total_amount,
       COUNT(r.id) AS record_count
FROM events e
LEFT JOIN records r ON r.event_id = e.id AND r.is_online = 0
WHERE NOT EXISTS (
  SELECT 1 FROM records WHERE event_id = e.id AND is_online = 1
)
GROUP BY e.id
ORDER BY e.date DESC, e.id DESC
```

用户确认过"一般不会出现情况 X(同一 event 既有电切又有现场)",所以实际上 NOT EXISTS 子句在常规场景下是防御性的 —— 真出现了就按"整场隐藏"处理。

## 场地/开关的 UI 联动

```
┌─────────────────────────────────┐
│ [添加切奇记录]                    │
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ 🔘 电切               [off] │ │  ← 新增第一行
│ └─────────────────────────────┘ │
│                                 │
│ 日期: 2026-04-21                │
│ 数量: ___                       │
│ 单价: 60                        │
│ 场地: [                    ▾]   │  ← 正常可编辑
│ 活动: [                    ▾]   │
└─────────────────────────────────┘

开关打开后:

┌─────────────────────────────────┐
│ 🔘 电切                  [on]   │
│                                 │
│ 日期: 2026-04-21                │
│ 数量: ___                       │
│ 单价: 60                        │
│ 场地: 电切                  🔒  │  ← 锁定为"电切",不可编辑
│ 活动: [                    ▾]   │
└─────────────────────────────────┘
```

切换行为:
- OFF → ON:场地字段清空原内容,填入 canonical `电切`(通过 `canonicalVenueFor('电切') ?? '电切'`),禁用输入
- ON → OFF:场地字段清空,启用输入,用户重填

### 为什么锁死场地而不是让用户随便填

保持 canonical: 电切场地只能有一个字符串形式(`电切`),避免用户手滑写成"電切"之类变体污染 venue 下拉历史。迁移回填也只认这一个规范值,以后导入/归并更稳。

## 去重键为什么要加 `is_online`

场景:同一天同一场同一偶像,用户既在现场留了切、又在电切上留了切(虽然罕见,但用户说"一般不会"= 可能发生)。如果去重键不含 `is_online`,两条记录会被 CSV 导入逻辑视为同一条,第二次导入时会丢一条。加入后此场景两条记录 `(...相同字段..., is_online=0)` 与 `(..., is_online=1)` 判为不同,保留两条。

NULL `event_id` 语义继续用 `IS` 比较,这部分已有实现。新键的 SQL 谓词追加 `AND is_online = ?` 即可(integer 不涉及 NULL 语义问题)。

## CSV 向后兼容策略

现状: csv_service 已支持 9 列/11 列/12 列三种长度(9 走 legacy B 行,11/12 各有路由)。新增 13 列后,路由表为:

| 列数 | 路径 | is_online 默认 |
|------|------|---------------|
| 9    | B(legacy) | 0 |
| 11/12 | 原有逻辑 | 0 |
| 13   | 新逻辑,读第 13 列 | 取 CSV 值 |

理由:老数据一律按现场对待(最保守假设)。若用户想把老数据中的电切识别出来,靠迁移阶段的 `UPDATE ... WHERE LOWER(venue) LIKE '%电切%'` 完成,CSV 导入不负责识别。

## 详情页 subtitle 布局

当前:

```
ListTile
  title:    2026-04-15  3切 ¥180
  subtitle: 下北沢SHELTER · 单价¥60
```

改为:

```
ListTile
  title:    2026-04-15  3切 ¥180
  subtitle: Column(
    [activeName]  (若 event_id 非 NULL)
    "${venue} · 单价¥${unitPrice}"
  )
```

实现上把 `subtitle: Text(...)` 换成 `subtitle: Column(...)` 即可。电切记录的 venue 字段就是"电切",不需要额外标记或图标 —— 用户已确认场地字段自然承载这个信息。

## 迁移回填的保守边界

```sql
UPDATE records
SET is_online = 1
WHERE LOWER(venue) LIKE '%电切%'
   OR LOWER(venue) LIKE '%電切%'
```

仅覆盖"venue 包含'电切'子串"的历史记录。不用更宽泛的匹配(比如"電チェキ"日文字符),因为这会误判。如果用户历史数据里有日文场地名含"チェキ",让她手动修正(或先导出 CSV 编辑 `电切` 列后重导入)。

## 不做的事

- **不做"电切"作为一级浏览入口**:现在用户只是想把它从总览里摘掉,还没有"单独看所有电切记录"的需求。
- **不改统计页的聚合口径**:月度花费、总切数这些照常合并计算(电切也花了钱也留了切,不分开)。将来要分的时候再开提案。
- **不自动迁移 venue 字符串**:回填只动 `is_online` 列,`venue = '电切'` 保持原样(否则详情页 subtitle 就看不到"电切"字样了)。
- **不对 `event_id` 建 FK 约束**:遵循已有规范(SQLite 默认不执行 FK),应用层保证引用完整性。
