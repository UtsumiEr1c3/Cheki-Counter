## Context

统计页 `StatisticsPage` 通过 `IdolRepository.getAllWithAggregates(sortBy, year)` 获取偶像列表。该方法使用 `LEFT JOIN records` 并在 JOIN 条件中加年份过滤。由于 LEFT JOIN 的语义，即使某偶像在所选年份无任何记录，仍会返回该偶像（聚合值为 0）。

## Goals / Non-Goals

**Goals:**
- 当用户在统计页选择具体年份时，只返回该年有记录的偶像

**Non-Goals:**
- 不改变"全部"模式的行为
- 不改变主界面 (`HomePage`) 的查询逻辑
- 不改变 UI 层代码

## Decisions

**D1: 年份筛选时使用 INNER JOIN 替代 LEFT JOIN**

当 `year` 参数非空时，将 SQL 从 `LEFT JOIN ... AND year_filter` 改为 `INNER JOIN ... WHERE year_filter`。

| 候选方案 | 描述 | 优劣 |
|----------|------|------|
| A. INNER JOIN（选定） | year 非空时改用 INNER JOIN + WHERE | 数据库层直接过滤，不返回无用行 |
| B. HAVING total_count > 0 | 保持 LEFT JOIN，加 HAVING 子句 | 同样有效，但语义不如 INNER JOIN 直接 |
| C. Dart 层过滤 | SQL 不变，在 Dart 中 `.where()` | 仍拉取无用数据，浪费 I/O |

选 A 的原因：语义最清晰 — "只取有记录的偶像"天然对应 INNER JOIN；无额外内存开销；改动最小（同一个方法内条件分支）。

## Risks / Trade-offs

**[风险] year=null 路径回归** — 需确保"全部"模式仍使用 LEFT JOIN，不丢失偶像。
→ Mitigation：year=null 时代码路径不变，仅 year 非空时切换 JOIN 类型。

**[风险] 主界面也调用 getAllWithAggregates** — 主界面始终传 year=null，不受影响。
→ Mitigation：无需额外处理，行为自然正确。
