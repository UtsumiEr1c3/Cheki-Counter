## Context

这是一个离线的个人记账类 App,用来记录地下偶像切奇(拍立得)并做统计。用户是单人(无账号、无同步),主要使用场景是 livehouse 现场或结束后补录;数据规模很小(单人年记录量可能几百到千条)。现有数据 `counts.csv` 已经是新 schema 的 67 行种子,App 必须能导入它。

前期探索确认:

- 技术栈:Flutter(用户不熟前端生态,Flutter 的 APK 打包和 UI 一致性都较稳)。
- 业务主键:(名字 + 应援色 + 团体)三元组;改任一字段 = 新偶像。
- 偶像派生于记录:不允许"有偶像无记录"的空状态。
- 只能删单条记录;最后一条被删时偶像随之消失。

## Goals / Non-Goals

**Goals:**

- 一份 Flutter 代码,能构建出可直装的 Android APK。
- 主界面、个人页、统计页、设置页四个屏幕 + 两个弹窗(添加记录 / 新建偶像)。
- 本地 SQLite 存储,启动即用,无网络依赖。
- CSV 导入导出与 `counts.csv` 格式互通,导入语义为"合并追加",不清空现有数据。
- 饼图 + 两种折线图(按日 / 按月)的可视化。
- 应援色预设色板覆盖参考图上的 20 种格子色。

**Non-Goals:**

- iOS 构建、桌面构建、Web 构建(代码不阻止,但本次不打包)。
- 云同步、多账号、登录、备份到云盘(用户自己用 CSV 手动备份)。
- 偶像字段的原地编辑(改名/改色/换团 = 新建)。
- 同名同色同团的二义性区分(方案 X 明确允许合并)。
- 国际化:仅简体中文。
- 深色模式(第一版不做,留未来扩展)。

## Decisions

### D1. 数据模型:双表,idols 由 records 派生维护

```
idols                               records
──────────                          ──────────────
id            INTEGER PK            id             INTEGER PK
name          TEXT NOT NULL         idol_id        INTEGER FK → idols.id
color         TEXT NOT NULL         date           TEXT (YYYY-MM-DD)
group_name    TEXT NOT NULL         count          INTEGER
created_at    TEXT                  unit_price     INTEGER
                                    subtotal       INTEGER  -- 冗余,= count*unit_price
UNIQUE (name, color, group_name)    venue          TEXT
                                    created_at     TEXT
```

**为什么不一张大宽表**:统计查询会对偶像维度聚合非常频繁(主界面、饼图、排行榜),双表让偶像卡片的渲染只扫 `idols` + 一次聚合 join,远比每次 `SELECT DISTINCT name,color,group_name FROM records` 便宜;并且让"新建偶像"这个动作有一个真实的写入目标(即使首条记录在同一个事务里写)。

**为什么 idols 仍然派生**:业务规则"删除最后一条记录时偶像消失"让 idols 的生命周期绑定在 records 上。实现上用一个事务包住 `INSERT/DELETE record` 的操作,在同一个事务里检查该 `idol_id` 是否还有记录,没有就 `DELETE FROM idols`。不用 SQL 触发器(Flutter 的 sqflite 对触发器支持够用但调试麻烦)。

**为什么 subtotal 冗余存一份**:导出 CSV 时 `小计` 列期望和输入时一致(浮点两位小数保留原始写法)。存一份避免"读时计算"和"写入时计算"可能的舍入分歧,也方便后续万一出现促销/折扣时单独记录。

**候选对比**:

| 方案 | 读性能 | 写复杂度 | 支持空偶像 | CSV 互通 |
|---|---|---|---|---|
| 单表(records 内冗余偶像字段) | 中 | 低 | ❌ | 直接 |
| 双表 + 级联清理(选定) | 高 | 中 | ❌(规则要求) | 导出时 join |
| 双表 + idols 独立生命周期 | 高 | 低 | ✅ | 需要两段 CSV |

### D2. CSV 合并规则(导入)

CSV 的 `ID` 列是**名字**,不是内部 id。导入算法:

```
for each row in csv:
    key = (row.name, row.color, row.group)
    idol = SELECT * FROM idols WHERE (name,color,group) = key
    if not idol:
        idol = INSERT INTO idols (name,color,group) VALUES key
    # 防重复:同一 (idol_id, date, count, unit_price, venue, created_at) 不再插
    exists = SELECT 1 FROM records WHERE
        idol_id = idol.id
        AND date = row.date
        AND count = row.count
        AND unit_price = row.unit_price
        AND venue = row.venue
        AND created_at = row.created_at
    if not exists:
        INSERT INTO records (...)
```

**为什么用 `created_at` 参与去重**:它是导入时唯一能做"这一行是不是之前导出过的同一条"判断的字段。如果去重不包含它,用户两场不同 livehouse 碰巧场地、数量、日期、单价都一样的记录会被误合并。

**为什么不做"导入前清空"模式**:用户没要求;默认合并追加最安全,风险最小。如果以后要支持"全量替换",加一个 checkbox 就行。

### D3. 应援色预设色板

看参考图,AddChekiPopup 里是 4×5 = 20 个固定色格子,用户在里面选一个。代码里维护一张预设色表(中文名 → hex),例如:

```
红色  #E53935    橙色  #FB8C00    黄色  #FDD835    绿色  #43A047
蓝色  #1E88E5    紫色  #8E24AA    粉色  #EC407A    白色  #FFFFFF
... (共 20)
```

CSV 存的是**中文色名**(跟现在 counts.csv 一致),不是 hex。App 内部显示颜色时查表。

**为什么不直接存 hex**:用户手工编辑 CSV 会用中文;跨设备/跨版本也更稳(万一调色值也不会搞丢老数据)。

**风险**:如果 CSV 出现不在预设表里的中文色名(用户手工改坏),导入时该行用"未知色(灰色)"兜底并在导入报告里提示。

### D4. 状态管理与分层

```
lib/
├── main.dart
├── app.dart                      # MaterialApp + 路由
├── data/
│   ├── db.dart                   # sqflite 打开 + schema 迁移
│   ├── models/idol.dart
│   ├── models/record.dart
│   ├── idol_repository.dart      # CRUD + 聚合查询
│   ├── record_repository.dart
│   └── csv_service.dart          # 解析 / 合并 / 导出
├── features/
│   ├── home/home_page.dart       # 主界面 + 卡片网格
│   ├── home/idol_card.dart
│   ├── home/add_idol_dialog.dart
│   ├── home/add_record_dialog.dart
│   ├── idol_detail/idol_detail_page.dart
│   ├── statistics/statistics_page.dart
│   ├── statistics/group_overview_page.dart
│   └── settings/settings_page.dart
└── shared/
    ├── colors.dart               # 应援色预设表
    └── formatters.dart
```

**状态管理选 `provider`(或 `riverpod`)**:这个 App 的数据流非常简单 —— 一个全局 `IdolListNotifier` 持有主界面数据,写操作后 notifyListeners 刷新。上 BLoC 过度;纯 `setState` 又让跨屏幕刷新(比如在 detail 页删记录要让 home 更新)不好处理。**倾向 `provider`**,社区成熟、学习曲线低。

### D5. 统计查询策略

统计页、个人页都会做聚合。所有聚合都用 SQL 直接算,不在 Dart 里遍历内存:

```sql
-- 主界面卡片数据
SELECT i.id, i.name, i.color, i.group_name,
       COALESCE(SUM(r.count),0) AS total_count,
       COALESCE(SUM(r.subtotal),0) AS total_amount
FROM idols i LEFT JOIN records r ON r.idol_id = i.id
GROUP BY i.id
ORDER BY total_count DESC;   -- 或 total_amount DESC

-- 年份筛选:只需要 records.date 前四位过滤
WHERE strftime('%Y', r.date) = :year

-- 折线图按月
SELECT strftime('%Y-%m', date) AS ym, SUM(count)
FROM records WHERE idol_id = :id GROUP BY ym ORDER BY ym;

-- 折线图按日(稀疏,只给有记录的日期)
SELECT date, SUM(count) FROM records
WHERE idol_id = :id GROUP BY date ORDER BY date;

-- 年份下拉候选
SELECT DISTINCT strftime('%Y', date) FROM records ORDER BY 1 DESC;
```

**为什么存 `YYYY-MM-DD` 字符串而不是 INTEGER timestamp**:CSV 往返简单、`strftime` 可直接切年月、肉眼可读。数据量小,性能不是瓶颈。

### D6. 折线图语义(来自探索期约定)

- **按日模式**:X 轴 = 日期,Y 轴 = 当日数量汇总。**只绘制有记录的日期,缺日不补 0 也不连线**(散点+断线)。
- **按月模式**:X 轴 = 月份,Y 轴 = 当月累计数量,**连续连线**。没记录的月份补 0 保证连线不跳。

fl_chart 的 LineChart 支持按 spot 画断点;按日模式用 `isCurved: false` + 每段短折线;按月用普通连线。

### D7. 添加记录的默认值

- **日期**:今天(`DateTime.now`)。
- **单价**:该偶像**最近一次**的 `unit_price`;如果是新建偶像走的 popup,默认 60。
- **数量**:空,必填。
- **场地**:空,必填。

### D8. 导出 CSV 的行顺序

按 `created_at DESC`(最近加的在上),跟主界面添加的直觉一致。字段编码 UTF-8 BOM(给 Excel 看不乱码),分隔符 `,`,字段内含逗号或换行时用双引号包裹 + 双引号转义(标准 RFC4180)。

### D9. 文件保存位置

- **导出**:通过 `share_plus` 让用户选"分享到"(含保存到本地),不硬写到某个路径 —— Android 11+ 的 scoped storage 下这最省事。
- **导入**:`file_picker` 让用户选 `.csv` 文件,读字节后解析。

## Risks / Trade-offs

- **[风险] CSV 合并规则可能重复插入行**:去重键依赖 `created_at` 完全一致。如果用户手工改过时间戳、或者同一文件被两种不同时间格式导出后再导入,会出现重复。**Mitigation**:导入后显示摘要"新增 N 条,跳过 M 条",让用户能察觉;提供"撤销上次导入"的尝试(可选,留到 v2)。

- **[风险] 三元组合并掉真正的同名同色同团偶像**:用户明确接受方案 X 的代价,但未来某一天真碰上,数据会合并。**Mitigation**:文档和设置页写清合并规则;v2 可加"按行 UID 强制区分"的可选列。

- **[风险] Flutter APK 包体**:fl_chart + sqflite + 各 plugin 下来大概 20MB+。对于单人用的工具 App 可接受。**Mitigation**:release 构建开 `--split-per-abi`,arm64 用户只下 ~12MB。

- **[风险] 偶像卡片网格在 20+ 偶像时布局**:参考图是 3 列卡片。卡片数量多时需要滚动。**Mitigation**:用 `GridView.builder` 懒加载,不一次性 build 全部。

- **[取舍] 不做触发器 / 外键级联**:手动在事务里清理 idols。好处是行为显式可测,坏处是每次写入多一次查询。数据量小,忽略成本。

- **[取舍] 不上 Riverpod / BLoC**:provider 够用。坏处是如果需求膨胀(比如未来加离线队列、云同步),重构有成本。

## Migration Plan

不适用 —— 首次发布,无历史 App 数据。种子数据由用户首次打开后通过设置页"导入 CSV"主动导入 `counts.csv`。
