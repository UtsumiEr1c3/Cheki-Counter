# records Specification

## Purpose
定义切奇记录(`records`)的数据模型、录入 popup 交互、与活动的可空关联语义、场地归一化、单价默认值、删除策略与跨路径去重键,是应用最核心的数据实体规范。

## Requirements

### Requirement: 添加切奇记录 popup 字段约束

添加切奇记录 popup SHALL 显示偶像名、应援色、团体三个锁定(不可编辑)字段,以及日期、数量、单价、场地四个用户必填字段,以及活动一个可选字段和电切一个布尔开关。popup 提交 SHALL 向 `records` 插入一条新记录,并在同一事务内更新所属偶像的派生汇总;若活动字段有值,同一事务内对 `events` 执行 upsert 并将返回的 `event.id` 写入 `records.event_id`;电切开关状态 SHALL 写入 `records.is_online`。场地字段 SHALL 以"可打字 + 历史下拉"的组合控件形式展示,下拉项 SHALL 来自 `records.venue` UNION `events.venue` 的 DISTINCT 集合,按最近一次使用时间(`records.created_at` 与 `events.created_at` 中该 venue 的最大值)降序排列,用户输入时按子串(case-insensitive)实时过滤下拉项。电切开关 ON 时场地字段 SHALL 被锁定为 `电切` 且禁用编辑。

#### Scenario: 锁定字段不可修改

- **WHEN** 用户从偶像卡片 `+` 打开添加切奇 popup
- **THEN** 偶像名、应援色、团体字段以禁用样式展示,用户无法修改

#### Scenario: 数量与单价必须为正整数

- **WHEN** 用户在 popup 中将数量或单价填写为 0、负数、非数字或空
- **THEN** 系统拒绝提交并在对应字段下方显示错误提示

#### Scenario: 场地必填

- **WHEN** 用户未填写场地点击提交
- **THEN** 系统拒绝提交并提示"请填写场地"

#### Scenario: 活动字段可选

- **WHEN** 用户未填写活动字段点击提交
- **THEN** 系统接受提交,`records.event_id` 写入 NULL

#### Scenario: 电切开关默认关闭

- **WHEN** 用户首次打开 AddRecordDialog
- **THEN** 电切开关 SHALL 处于 OFF 状态,场地字段可正常编辑

#### Scenario: 电切开关 ON 时场地锁定为"电切"

- **WHEN** 用户将电切开关切换为 ON
- **THEN** 场地字段 SHALL 立即显示 `电切` 且禁用编辑

#### Scenario: 日期默认为今天

- **WHEN** popup 首次打开
- **THEN** 日期字段预填为设备当前日期(YYYY-MM-DD)

#### Scenario: 场地字段聚焦时显示历史下拉

- **WHEN** 用户聚焦场地字段且输入为空(且电切开关 OFF)
- **THEN** 系统显示历史场地下拉列表,来源为 `records.venue` 与 `events.venue` 的并集(DISTINCT),按最近一次使用时间降序排列

#### Scenario: 场地字段按子串过滤

- **WHEN** 用户在场地字段输入 `电切`,且历史中存在 `武汉电切 / 北京电切 / 长沙电切` 以及 `武汉Beach No.11`
- **THEN** 下拉 MUST 只显示 `武汉电切 / 北京电切 / 长沙电切`(包含子串 `电切` 的项),不显示 `武汉Beach No.11`;匹配 MUST 对大小写不敏感

#### Scenario: 场地字段无历史数据时降级为普通输入

- **WHEN** 用户首次使用且 `records` 与 `events` 两表中都无任何 venue 记录
- **THEN** 场地字段行为等同普通文本输入框,不弹出下拉 overlay

#### Scenario: 场地字段允许输入下拉外的新值

- **WHEN** 用户输入 `上海虹馆`,且历史中不存在任何 case-insensitive 匹配的场地
- **THEN** 系统接受该输入,提交后写入 `records.venue = '上海虹馆'`;下次打开 popup 时该场地 MUST 出现在下拉列表里

### Requirement: 切奇记录关联活动(可空)

系统 SHALL 在 `records` 表上新增 `event_id INTEGER NULL` 列,指向 `events(id)`。`event_id = NULL` 表示该记录未关联任何活动(legacy 切奇或用户显式未选活动);`event_id ≠ NULL` 表示该记录归属于指定活动。系统 NOT 对 `event_id` 建立强制 FK 约束(SQLite 默认不执行),应用层 SHALL 保证引用完整性:删除一个 `event` 时(若未来版本提供),关联 records 的 `event_id` SHALL 被置回 NULL 而非级联删除。

#### Scenario: 老数据 event_id 保持 NULL

- **WHEN** DB 从 v1 升级到 v2 后,用户查看既有切奇记录
- **THEN** 所有老记录的 `event_id` SHALL 为 NULL;显示与统计行为与升级前一致

#### Scenario: 新增带活动的切奇

- **WHEN** 用户在 AddRecordDialog 中选定活动 `('VoltFes 2.0', '武汉MAO', '2026-04-20')` 并提交
- **THEN** 插入的 `records` 行的 `event_id` SHALL 等于该 `events.id`

#### Scenario: 新增不选活动的切奇

- **WHEN** 用户在 AddRecordDialog 中留空活动字段并提交
- **THEN** 插入的 `records` 行的 `event_id` SHALL 为 NULL

### Requirement: AddRecordDialog 活动字段

系统 SHALL 在添加切奇 popup 中新增"活动"字段,字段位置位于场地字段之后、是可选字段(留空允许提交)。字段 SHALL 采用"可打字 + 历史下拉"控件:下拉项来自 `events` 表,按 `(name)` 子串过滤(大小写不敏感),按 `events.created_at` 降序。用户可以:(a) 从下拉选已有 event,(b) 输入全新活动名提交(同步 upsert event)。若用户选了已有 event,场地与日期字段 SHOULD 自动填充为该 event 的 venue 与 date(用户仍可修改;若修改后与已选 event 不一致,提交时以表单字段为准并 upsert 为新 event)。若用户输入了活动名但未填场地或日期,提交时以表单当前场地和日期字段的值作为 event 的 venue 和 date。

#### Scenario: 字段可选,空提交走 legacy 路径

- **WHEN** 用户打开 AddRecordDialog,填完其它必填项,活动字段留空,点击提交
- **THEN** 记录正常写入,`event_id = NULL`

#### Scenario: 选已有活动自动填充场地日期

- **WHEN** 用户在活动字段下拉选中 `('VoltFes 2.0', '武汉MAO', '2026-04-20')`
- **THEN** 场地字段 SHALL 预填 `'武汉MAO'`,日期字段 SHALL 预填 `'2026-04-20'`

#### Scenario: 输入新活动名同步 upsert

- **WHEN** 用户在活动字段输入 `'定期公演'`(`events` 中不存在该三元组)且场地填 `'武汉电切'`、日期填 `'2026-04-21'`,提交
- **THEN** 系统先 INSERT `events('定期公演', '武汉电切', '2026-04-21')`,取回 `event.id`,再 INSERT `records` 并挂 `event_id = event.id`(同一事务)

#### Scenario: 输入已存在三元组复用

- **WHEN** 用户输入的活动名、场地、日期组成的三元组已在 `events` 存在
- **THEN** 系统 NOT 新增 event,直接复用已有 `event.id`

### Requirement: 场地字段归一化策略

系统 SHALL 在提交切奇记录前对用户输入的场地字段执行归一化:先 `trim()` 去除首尾空白,再在 `records.venue` 与 `events.venue` 的并集中查找 case-insensitive 相同的已存在字符串;若存在,采用该已存在字符串作为写入值(canonical);若不存在,按 trim 后的原样写入。由此保证同一场地在 DB 中始终只有一个字符串形式,DISTINCT 查询与 CSV 导出不出现"仅大小写不同"的重复项。

#### Scenario: 新场地按原样保存

- **WHEN** 用户输入 `南京无忌演艺空间`,`records` 与 `events` 两表中不存在任何 case-insensitive 相同的 venue
- **THEN** 写入的 venue 字段 = `'南京无忌演艺空间'`(仅 trim)

#### Scenario: 已有场地大小写不同被归一化

- **WHEN** `records.venue` 中已存在 `'Beach No.11'`,用户本次在 AddRecordDialog 或 AddEventDialog 输入 `beach no.11`
- **THEN** 写入值 MUST 等于 `'Beach No.11'`(采用已存在字符串)

#### Scenario: 空格差异不被视为同一场地

- **WHEN** `records` 表中已存在 `venue = 'Beach No.11'`,用户本次输入 `Beach No. 11`(中间多一个空格)
- **THEN** 归一化 MUST NOT 合并两者,写入的 venue 字段 = `'Beach No. 11'`(作为新场地保存)

#### Scenario: CSV 导入不触发归一化

- **WHEN** 用户通过"导入 CSV"合并追加一份数据,文件中包含 `venue = 'beach no.11'` 的行,而 DB 中已有 `venue = 'Beach No.11'`
- **THEN** 导入流程 SHALL 将源 venue 原样写入

#### Scenario: 场地归一化适用路径

- **WHEN** 归一化策略的生效路径
- **THEN** 仅包括 `AddRecordDialog`、`AddIdolDialog`、`AddEventDialog` 三处手动录入入口;其它写入路径(CSV 导入、未来可能的批量操作)不经过本策略

### Requirement: 单价默认值策略

系统 SHALL 在添加切奇 popup 的单价字段预填默认值:若为已存在偶像,默认值取该偶像按 `created_at` 排序最近一次记录的 `unit_price`;若为全新偶像(通过新建偶像 popup 触发),默认值为 60。

#### Scenario: 已有偶像使用最近单价

- **WHEN** 小五最近一条记录单价为 70,用户从小五卡片的 `+` 打开 popup
- **THEN** 单价字段预填 70

#### Scenario: 新偶像使用 60 作为兜底

- **WHEN** 用户从主界面右下角 `+` 新建偶像
- **THEN** popup 的单价字段预填 60

### Requirement: 小计由数量与单价派生

系统 SHALL 在记录写入时将 `subtotal = count * unit_price` 作为整数持久化到 `records.subtotal`,不在读取时重新计算。

#### Scenario: 写入时计算小计

- **WHEN** 用户提交数量=3、单价=70 的记录
- **THEN** `records` 行的 `subtotal` 字段值为 210

### Requirement: 单条记录删除

系统 SHALL 允许用户在偶像详情页的记录列表中删除任意单条切奇记录。删除 SHALL 在事务中执行,并在删除后检查所属偶像是否还有剩余记录,若无则同时删除 `idols` 行。删除 records 行 NOT 触发对其 `event_id` 所指向 `events` 行的联动清理;即便被删 records 是该 event 的最后一条关联,`events` 行仍然保留(降级为纯打卡活动)。

#### Scenario: 删除非最后一条记录

- **WHEN** 某偶像有 5 条记录,用户删除其中第 3 条
- **THEN** 该偶像仍保留在主界面,`idols` 行不变,剩余 4 条记录和偶像汇总据此更新

#### Scenario: 删除最后一条记录连带删除偶像

- **WHEN** 某偶像只剩一条记录,用户删除它
- **THEN** `records` 行和 `idols` 行在同一事务中被删除,主界面不再显示该偶像

#### Scenario: 删除带 event_id 的记录不影响 event

- **WHEN** 某 `records` 行 `event_id = 5`,用户删除它,且该记录是 `event_id = 5` 对应 event 的最后一条关联
- **THEN** `records` 行被删除,`events` 行 id=5 保留;该 event 在偶活总览中从"有切奇"降级为"(未切奇)"

#### Scenario: 系统不提供批量删除或记录编辑

- **WHEN** 用户在记录列表中长按或多选
- **THEN** 系统 NOT 提供批量删除或就地编辑操作;唯一的修改方式是"删除后重新添加"

### Requirement: 去重键约束

系统 SHALL 使用 `(idol_id, date, count, unit_price, venue, created_at, event_id, is_online)` 作为 records 去重键。该键在 CSV 导入时用于跳过已存在的行,在 UI 层无直接表现。NULL `event_id` 之间的等值比较 MUST 使用 SQL `IS` 语义(`NULL IS NULL` 为真);`is_online` 为 INTEGER 非空字段,使用标准 `=` 比较。

#### Scenario: 完全相同的行视为重复

- **WHEN** 两行在所有 8 个键字段上逐一相等
- **THEN** 视为同一条记录

#### Scenario: 同场同偶像现场与电切不合并

- **WHEN** 两行 `(idol_id, date, count, unit_price, venue, created_at, event_id)` 七字段均相同,但一条 `is_online = 0`、另一条 `is_online = 1`
- **THEN** 视为两条不同记录,均应插入成功

#### Scenario: 昼夜公演不被错误合并

- **WHEN** 两行六字段(不含 event_id 与 is_online)均相同,但 `event_id` 一个是"昼公演 event.id",另一个是"夜公演 event.id"
- **THEN** 视为两条不同记录,均应插入成功

#### Scenario: legacy 行之间以 NULL = NULL 判重

- **WHEN** 两行六字段(不含 event_id 与 is_online)均相同,且 `event_id` 均为 NULL,且 `is_online` 均为 0
- **THEN** 视为同一条记录,第二条被去重

### Requirement: 电切记录标记

系统 SHALL 在 `records` 表上新增 `is_online INTEGER NOT NULL DEFAULT 0` 列,用于区分"现场留切"(`is_online = 0`)与"电切"(`is_online = 1`,即通过电话/远程等方式获得切奇,用户并未到活动现场)。DB schema 从 v2 升级到 v3;升级时 SHALL 执行一次性回填:对 `LOWER(venue) LIKE '%电切%'` 或 `LOWER(venue) LIKE '%電切%'` 的历史记录设置 `is_online = 1`,其它记录保持 `is_online = 0`。电切记录 MAY 仍然关联 `event_id`(电切有对应的真实活动),但 SHALL 在偶活总览查询中触发"整场隐藏"过滤(详见 events capability)。电切记录 SHALL 计入小偶像的总切数、总金额与折线图聚合,与现场记录等权重。

#### Scenario: 升级时回填 venue 为"电切"的老记录

- **WHEN** 用户从 v2 升级到 v3,DB 中存在记录 `(venue='电切', ...)` 和 `(venue='Beach No.11', ...)`
- **THEN** 升级完成后,第一条记录的 `is_online = 1`,第二条 `is_online = 0`

#### Scenario: 大小写与繁简变体的 venue 被识别

- **WHEN** 升级前 DB 中存在 `venue='电切'`、`venue='電切'`、`venue='北京电切'` 的记录
- **THEN** 三条记录的 `is_online` 在升级后均为 1

#### Scenario: 非电切 venue 不受影响

- **WHEN** 升级前 DB 中 `venue='上海虹馆'` 的记录
- **THEN** 升级后该记录 `is_online = 0`

#### Scenario: 电切记录计入偶像总切数

- **WHEN** 小五有 3 条现场记录(共 5 切)和 1 条电切记录(1 切)
- **THEN** 小偶像详情页显示总切数 6,总金额按全部 6 切的 subtotal 合计

### Requirement: AddRecordDialog 电切开关

系统 SHALL 在 AddRecordDialog 顶部新增"电切"开关(Switch 控件),默认关闭。开关打开 SHALL 触发以下联动:(a) 场地字段清空既有输入,填入 canonical `电切`;(b) 场地字段禁用编辑与下拉 overlay;(c) 提交时 `records.is_online = 1`。开关关闭 SHALL 恢复场地字段可编辑、清空内容、`records.is_online = 0`。活动字段(可选)在电切开关打开时仍然可填 —— 电切可以有关联活动。

#### Scenario: 开关 ON 时场地自动填"电切"

- **WHEN** 用户打开 AddRecordDialog,将"电切"开关切换为 ON
- **THEN** 场地字段 SHALL 立刻显示 `电切`,且禁用编辑

#### Scenario: 开关 ON 时提交写入 is_online=1

- **WHEN** 用户在开关 ON 状态下填完其它必填项并提交
- **THEN** 插入的 `records` 行 `is_online = 1`,`venue = '电切'`

#### Scenario: 开关从 ON 切回 OFF 清空场地

- **WHEN** 用户将开关从 ON 切回 OFF
- **THEN** 场地字段 SHALL 清空,恢复可编辑,用户需重新填写

#### Scenario: 电切记录仍可关联活动

- **WHEN** 用户在开关 ON 状态下同时填写活动字段 `'3rd Anniversary 特典会'`
- **THEN** 提交后 `records.event_id` 指向该 event,`records.is_online = 1`

#### Scenario: 开关 OFF 时写入 is_online=0

- **WHEN** 用户不碰电切开关,正常填现场场地并提交
- **THEN** 插入的 `records` 行 `is_online = 0`

### Requirement: 小偶像详情页记录列表展示活动名

系统 SHALL 在偶像详情页的记录列表中,为每条切奇记录在 `ListTile.subtitle` 区域额外展示所属活动名(若 `records.event_id` 非 NULL)。布局 SHALL 为两行:第一行活动名(单独一行,无前后缀图标),第二行 `${venue} · 单价¥${unitPrice}`。若 `event_id` 为 NULL,SHALL 只显示第二行(退化为单行 subtitle,等同当前行为)。电切记录的 venue 字段值本身即为 `电切`,不额外添加图标或标签。

#### Scenario: 有关联活动的记录显示两行

- **WHEN** 用户查看偶像详情页,某条记录 `event_id` 指向活动 `'春の LIVE 2026'`,venue = `'下北沢SHELTER'`,unitPrice = 60
- **THEN** 该记录的 ListTile subtitle SHALL 显示两行:第一行 `春の LIVE 2026`,第二行 `下北沢SHELTER · 单价¥60`

#### Scenario: 无关联活动的记录显示单行

- **WHEN** 某条记录 `event_id = NULL`,venue = `'下北沢SHELTER'`
- **THEN** subtitle SHALL 显示单行 `下北沢SHELTER · 单价¥60`

#### Scenario: 电切记录显示活动名与"电切"场地

- **WHEN** 某条记录 `is_online = 1`,event 为 `'3rd Anniversary 特典会'`,venue = `'电切'`
- **THEN** subtitle 两行分别显示 `3rd Anniversary 特典会` 与 `电切 · 单价¥60`
