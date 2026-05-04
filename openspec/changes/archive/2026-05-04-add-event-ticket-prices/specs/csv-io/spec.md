## MODIFIED Requirements

### Requirement: CSV 列格式

系统 SHALL 使用以下固定 14 列顺序读写 CSV:`偶像名,应援色,团体,日期,数量,单价,小计,场地,创建时间,活动名,活动场地,活动日期,电切,门票价格`。CSV 文件 SHALL 使用 UTF-8 编码并写入 BOM;SHALL 遵循 RFC 4180 对逗号、双引号、换行的转义。第 13 列 `电切` 值 SHALL 为 `'0'`(现场)或 `'1'`(电切);纯打卡活动行(C 行)第 13 列 SHALL 为 `'0'`。第 14 列 `门票价格` SHALL 为空或非负整数字符串;为空按 0 处理。无活动的 legacy 切奇行(B 行)第 14 列 SHALL 留空。

CSV 行按字段空/非空可表达三类语义:

- **A 行(有活动有切奇)**:前 12 列全部非空,第 13 列为 `'0'` 或 `'1'`,第 14 列为空或非负整数
- **B 行(legacy 切奇,无活动)**:前 9 列非空,第 10-12 列留空,第 13 列为 `'0'` 或 `'1'`,第 14 列留空
- **C 行(纯打卡,无切奇)**:前 6 列与第 7-8 列留空,第 9 列 `创建时间` 非空(记录 event 的 `created_at`),第 10-12 列活动字段非空,第 13 列为 `'0'`,第 14 列为空或非负整数

#### Scenario: 导出文件可被 Excel 正确打开

- **WHEN** 用户导出 CSV 并用 Excel 打开
- **THEN** 中文列名和中文字段值不乱码,列对齐;新列表头显示为 `电切` 和 `门票价格`

#### Scenario: 字段包含逗号时用双引号包裹

- **WHEN** 场地字段为 `不晚Intime, 车里子店`
- **THEN** 导出的该字段为 `"不晚Intime, 车里子店"`,导入时能恢复原值

#### Scenario: 三类行在同一文件共存

- **WHEN** 用户的 DB 同时包含有活动的新切奇、legacy 切奇、和纯打卡活动
- **THEN** 导出的 CSV 文件 SHALL 同时含 A、B、C 三类行,每行末尾带 `电切` 列值;有活动的行 SHALL 带 `门票价格` 列值,legacy 切奇行 SHALL 留空

#### Scenario: 电切记录导出为 1

- **WHEN** DB 中某条 record `is_online = 1`
- **THEN** 导出 CSV 对应行第 13 列为 `'1'`

#### Scenario: 活动门票价格导出

- **WHEN** DB 中某条 record 关联的 event `ticket_price = 180`
- **THEN** 导出 CSV 对应行第 14 列为 `'180'`

### Requirement: CSV 导入 - 合并追加语义

系统 SHALL 将 CSV 导入作为"合并追加",不清空现有数据。导入算法 SHALL 对每一行分两侧解析:

1. **活动侧**:若 `(活动名, 活动场地, 活动日期)` 三字段全非空,按 `UNIQUE(name, venue, date)` upsert `events` 行,取回 `event.id`;第 14 列存在且非空时解析为非负整数门票价格,缺列或空字符串按 0 处理;若三字段有缺,活动侧结果为 NULL 且门票价格忽略。
2. **记录侧**:若 `(偶像名, 应援色, 团体, 日期, 数量, 单价, 场地)` 全非空,按三元组定位或创建 `idols` 行;从第 13 列解析 `is_online`(`'1'` 映射为 1,其它值包括 `'0'`、空字符串、缺列均映射为 0);然后按去重键 `(idol_id, 日期, 数量, 单价, 场地, 创建时间, event_id, is_online)` 判断是否已存在对应 `records` 行,仅当不存在时插入;`event_id` 取自活动侧结果(活动侧为 NULL 则 records.event_id = NULL)。

若两侧都为空,本行视为错误。活动侧 upsert SHALL 按 events capability 的门票价格补写规则处理 `events.ticket_price`:新 event 写入解析出的门票价格;已存在 event 若旧 `ticket_price = 0` 且本行门票价格 `> 0`,则更新为本行门票价格;已存在 event 若旧 `ticket_price > 0`,则保持旧值。

#### Scenario: A 行同时创建活动与切奇

- **WHEN** CSV 中一行 14 列,活动三元组与记录三元组均本地不存在,电切列为 `'0'`,门票价格列为 `'180'`
- **THEN** 系统插入 1 个新 event(`ticket_price = 180`),插入 1 条新 record,record `is_online = 0`、`event_id` 指向该 event

#### Scenario: 电切行导入为 is_online = 1

- **WHEN** CSV 中一行记录字段完整,第 13 列为 `'1'`
- **THEN** 插入的 record `is_online = 1`

#### Scenario: B 行仅处理切奇侧

- **WHEN** CSV 中一行前 9 列非空、第 10-12 列留空,第 13 列为 `'0'` 或 `'1'`,第 14 列留空
- **THEN** 系统不触碰 `events` 表;若 records 去重键未存在则插入 `records`(event_id = NULL,`is_online` 按第 13 列)

#### Scenario: C 行仅处理活动侧

- **WHEN** CSV 中一行偶像/切奇字段留空,活动 3 列非空,第 13 列为 `'0'`,第 14 列为 `'180'`
- **THEN** 系统按三元组 upsert `events`,并按门票价格补写规则处理 `ticket_price`;`records` 表无变化

#### Scenario: 同场同偶像现场与电切同时存在不合并

- **WHEN** CSV 中两行 `(偶像名, 应援色, 团体, 日期, 数量, 单价, 场地, 创建时间)` 八字段完全相同,但一行电切列为 `'0'`、另一行为 `'1'`
- **THEN** 系统插入两条 records(去重键不同)

#### Scenario: 同一文件内多行共享同一活动

- **WHEN** CSV 中两行活动三列都为 `('VoltFes 2.0', '武汉MAO', '2026-04-20')`,门票价格列均为 `'180'`,偶像分别为小五和 Seiko
- **THEN** 系统 NOT 重复 INSERT events;两行 records 的 `event_id` 指向同一 `event.id`,该 event 的 `ticket_price = 180`

#### Scenario: 同一活动多行门票价格冲突时保留既有非零值

- **WHEN** CSV 中两行活动三列都为 `('VoltFes 2.0', '武汉MAO', '2026-04-20')`,第一行门票价格为 `'180'`,第二行为 `'220'`
- **THEN** 系统 SHALL 复用同一 event,并保持该 event 的 `ticket_price = 180`

#### Scenario: 已存在偶像追加新记录

- **WHEN** CSV 中 `(小五, 蓝色, EAUX)` 的一行,其去重键(含 is_online)不与本地任何现有记录完全相同
- **THEN** 系统复用已有 `idols` 行,插入一条新的 `records`

#### Scenario: 完全相同的行被跳过

- **WHEN** CSV 中某行的 8 字段去重键与本地已有 records 完全一致
- **THEN** 系统跳过该行 records 侧,不重复插入

#### Scenario: 两侧都空报错

- **WHEN** CSV 中某行偶像字段与活动字段都为空
- **THEN** 该行计入"错误"计数并记录行号与原因 "既无偶像也无活动",继续处理其他行

#### Scenario: 导入摘要反馈

- **WHEN** 导入结束
- **THEN** 系统弹出摘要对话框,显示 "新增偶像 N 个 / 新增活动 A 个 / 新增记录 M 条 / 跳过重复 K 条 / 错误 E 条"

### Requirement: CSV 导出

系统 SHALL 提供 CSV 导出功能。导出 SHALL 包含当前数据库中全部 `records` 及全部没有关联 records 的 `events`(纯打卡活动)。导出行按**演出日期**降序排列:有活动关联的 records 行使用 `events.date`,legacy records 使用 `records.date`,纯打卡 event 使用 `events.date`;同日 tie-break 使用 `records.id ASC`(records 侧)或 `events.id ASC`(events 侧)。每行字段来源:

- 偶像侧字段(列 0-8, 列 8 `创建时间` 用 `records.created_at`):来自 `records` JOIN `idols`
- 活动侧字段(列 10-12):若 `records.event_id` 非 NULL 则来自关联 `events`;否则留空
- 纯打卡 event 行:偶像/切奇字段全留空,列 8 `创建时间` 填 `events.created_at`,活动 3 列填 event 对应字段
- 小计(列 6)形式为保留两位小数的字符串(如 `60.00`),纯打卡行留空
- 电切(列 12,即第 13 列):records 行输出 `records.is_online`(`'0'` 或 `'1'`);纯打卡 event 行输出 `'0'`
- 门票价格(列 13,即第 14 列):有活动关联的 records 行输出关联 `events.ticket_price`;纯打卡 event 行输出 `events.ticket_price`;legacy records 行留空

#### Scenario: 导出后再导入产生零增量

- **WHEN** 用户导出 CSV 随后立即再次导入同一份文件
- **THEN** 导入摘要显示 "新增 0 条切奇 / 新增 0 个活动 / 跳过 N 条 / 错误 0 条"(N 等于 A+B+C 总行数)

#### Scenario: 导出按演出日期排序

- **WHEN** DB 中有三条 records,演出日期分别为 2026-04-19、2026-03-15、2025-12-31
- **THEN** 导出 CSV 按此顺序从上到下

#### Scenario: 纯打卡活动导出为 C 行且电切列为 0

- **WHEN** DB 中有一个 event 没有任何关联 records,且 `ticket_price = 180`
- **THEN** 导出 CSV 包含一行 C 行,第 13 列 `电切` 为 `'0'`,第 14 列 `门票价格` 为 `'180'`

#### Scenario: 电切 records 导出电切列为 1

- **WHEN** DB 中某条 record `is_online = 1`
- **THEN** 导出 CSV 对应行第 13 列为 `'1'`

#### Scenario: 有活动 records 导出门票价格

- **WHEN** DB 中某条 record 关联 event `ticket_price = 180`
- **THEN** 导出 CSV 对应行第 14 列为 `'180'`

#### Scenario: 导出通过系统分享面板

- **WHEN** 用户在设置页点击"导出 CSV"
- **THEN** 系统调用 Android 分享面板,让用户选择保存位置或发送到其他 App;系统不硬编码保存路径

### Requirement: 向后兼容 - 读 9/11/12 列老 CSV

系统 SHALL 支持导入使用旧列数格式的 CSV 文件(9 列 legacy、11/12 列的旧带活动格式、13 列带电切格式)。导入路径按列数做路由:

- 列数 = 9:首列 header 文本为 `'ID'` 或 `'偶像名'` 均可接受;活动侧 3 列按"留空"处理,整行走 B 行路径;`is_online` 默认 0;门票价格默认 0
- 列数 = 11 或 12:按原有活动字段解析逻辑;`is_online` 默认 0;门票价格默认 0
- 列数 = 13:按上一版本逻辑处理,第 13 列解析 `is_online`;门票价格默认 0
- 列数 >= 14:按新逻辑处理,第 13 列解析 `is_online`,第 14 列解析门票价格

#### Scenario: 导入 9 列 legacy CSV 走 B 行路径且电切默认 0

- **WHEN** 用户导入一个 9 列、首列 header 为 `'ID'` 的老 CSV 文件
- **THEN** 系统 NOT 报"列数不足"错误;每行插入 `records` 时 `event_id = NULL` 且 `is_online = 0`

#### Scenario: 导入 12 列 CSV 电切默认 0 且门票默认 0

- **WHEN** 用户导入上一版本导出的 12 列 CSV
- **THEN** 所有 records 插入时 `is_online = 0`;若该行创建 event,对应 event 的 `ticket_price = 0`

#### Scenario: 导入 13 列 CSV 门票默认 0

- **WHEN** 用户导入当前版本导出的 13 列 CSV
- **THEN** 系统 SHALL 正常解析第 13 列 `电切`;若该行创建 event,对应 event 的 `ticket_price = 0`

#### Scenario: 混合列数的 CSV 逐行判定

- **WHEN** 用户编辑的 CSV 文件首行 header 有 14 列,但某些数据行只有 9 列
- **THEN** 该行仍按实际列数解析;`is_online` 按实际列数规则默认 0,门票价格按实际列数规则默认 0

#### Scenario: 空白活动字段等价于列缺失

- **WHEN** CSV 行有 14 列但活动 3 列全为空字符串
- **THEN** 等价于 B 行路径;`events` 表无变化,records 按第 13 列插入,第 14 列门票价格被忽略

### Requirement: CSV 导入 - 错误兜底

系统 SHALL 对单行解析或校验失败的情况不中断整体导入:将该行计入摘要的"错误"计数并保留错误原因列表供用户查看,正常行继续处理。对非关键兜底字段,系统 SHALL 记录错误并使用默认值继续处理该行。

#### Scenario: 数量非数字

- **WHEN** 某行的 `数量` 列为 `abc`
- **THEN** 该行被跳过,错误计数 +1,错误列表记录行号与原因,其他行继续导入

#### Scenario: 应援色不在预设表

- **WHEN** 某行的 `应援色` 列为 `未知色`
- **THEN** 系统仍然接受该行,偶像被创建;UI 渲染该偶像时边框使用灰色兜底;导入摘要提示用户有 N 个未知色名

#### Scenario: 活动日期格式错误

- **WHEN** 某行的 `活动日期` 列为 `2026/4/20`(非 `YYYY-MM-DD`)
- **THEN** 活动侧解析失败,记录错误;若偶像侧齐全,仍可按 B 行路径插入 records(`event_id = NULL`,`is_online` 按第 13 列);若偶像侧也不全,则整行错误

#### Scenario: 电切列值非 0/1

- **WHEN** 某行第 13 列值为 `abc` 或 `2` 等非 `'0'`/`'1'` 值
- **THEN** 系统按 0 兜底处理(insert 时 `is_online = 0`),错误计数 +1,错误列表记录行号与原因 "电切列值无效,已按现场(0)处理";该行 records 仍正常插入

#### Scenario: 门票价格列值无效

- **WHEN** 某行第 14 列值为 `abc` 或 `-1` 等非非负整数值
- **THEN** 系统按 0 兜底处理活动侧门票价格,错误计数 +1,错误列表记录行号与原因 "门票价格无效,已按0处理";该行其它有效部分仍正常导入
