## MODIFIED Requirements

### Requirement: 偶像存在性由切奇记录派生

系统 SHALL 只保留至少有一条切奇记录的偶像;不允许"有偶像但零记录"的状态。偶像的本机稳定业务身份 SHALL 由 `idols.id` 唯一确定；偶像的对外导入导出身份 SHALL 由 `idols.stable_id` 唯一确定；`名字`、`应援色`、`团体` SHALL 表示该偶像的当前资料，并且当前三元组 `(名字, 应援色, 团体)` MUST 在 `idols` 表内保持唯一。新建偶像 popup (`AddIdolDialog`) 的"首条切奇记录"区域 SHALL 与 `AddRecordDialog` 字段齐平,包含日期、数量、单价、场地四个必填项,以及活动一个可选字段、门票价格一个可选字段和电切一个布尔开关。门票价格字段 SHALL 仅在活动字段非空时参与活动 upsert;留空 SHALL 按 0 处理,填写时 MUST 为非负整数。首条记录提交时:若活动字段非空,SHALL 对 `events` 执行 `upsertByTriple(活动名, 场地, 日期, 门票价格)` 并把返回的 `event.id` 写入该首条记录的 `event_id`,同时按 events capability 的门票价格补写规则处理 `events.ticket_price`;电切开关状态 SHALL 写入首条记录的 `is_online`。电切开关 ON 时场地字段 SHALL 被锁定为 canonical `电切` 且禁用编辑,与 `AddRecordDialog` 行为一致。

#### Scenario: 新建偶像必须附带首条记录

- **WHEN** 用户从主界面右下角 `+` 触发新建偶像流程,在 popup 内填写名字、应援色、团体,以及首条切奇的日期、数量、单价、场地
- **THEN** 系统在同一事务内插入一条带唯一 `stable_id` 的 `idols` 行和一条 `records` 行,偶像卡片出现在主界面

#### Scenario: 新建偶像 popup 的活动字段可选

- **WHEN** 用户在新建偶像 popup 的"活动(可选)"字段留空
- **THEN** 首条 `records` 行的 `event_id` 写入 NULL,不触碰 `events` 表

#### Scenario: 新建偶像 popup 填入活动名自动关联 event

- **WHEN** 用户在新建偶像 popup 的"活动(可选)"字段选中或输入一个活动名,场地与日期已填(或由活动选项回填),门票价格填 `180`
- **THEN** 系统 SHALL 对 `events` 执行 `upsertByTriple(活动名, 场地, 日期, 门票价格)`;首条 `records` 行的 `event_id` 指向该 event,对应 event 的 `ticket_price` 按 events capability 的补写规则处理

#### Scenario: 新建偶像 popup 选已有活动自动填充门票

- **WHEN** 用户在新建偶像 popup 的活动字段下拉选中 `('VoltFes 2.0', '武汉MAO', '2026-04-20', ticket_price=180)`
- **THEN** 场地字段 SHALL 预填 `'武汉MAO'`,日期字段 SHALL 预填 `'2026-04-20'`,门票价格字段 SHALL 预填 `180`

#### Scenario: 新建偶像 popup 门票价格必须为非负整数

- **WHEN** 用户在新建偶像 popup 将首条切奇区域的门票价格填写为负数或非数字
- **THEN** 系统拒绝提交并在门票价格字段下方显示错误提示

#### Scenario: 新建偶像 popup 电切开关默认关闭

- **WHEN** 用户首次打开新建偶像 popup
- **THEN** 电切开关 SHALL 处于 OFF 状态,场地字段可正常编辑,提交后首条记录 `is_online = 0`

#### Scenario: 新建偶像 popup 电切开关 ON 时场地锁定为"电切"

- **WHEN** 用户将新建偶像 popup 的电切开关切换为 ON
- **THEN** 场地字段 SHALL 立即显示 canonical `电切` 且禁用编辑;即使之后在活动字段选中已有活动,venue 仍保持为 `电切`,不被活动的 venue 覆盖;提交后首条记录 `is_online = 1`

#### Scenario: 删除偶像最后一条记录后偶像消失

- **WHEN** 某偶像只剩一条切奇记录,用户在该偶像详情页删除这条记录
- **THEN** 系统在同一事务内删除该记录并删除对应的 `idols` 行,主界面不再显示该偶像卡片

#### Scenario: 不存在空偶像的入口

- **WHEN** 用户尝试通过任何 UI 路径创建偶像
- **THEN** 系统 MUST 要求同时提供首条切奇记录的完整信息,否则拒绝提交

### Requirement: 偶像业务主键为三元组

系统 SHALL 使用 `idols.id` 作为偶像本机稳定身份，并使用 `idols.stable_id` 作为 CSV 导入导出的稳定身份。系统 SHALL 使用 `(名字, 应援色, 团体)` 三元组作为偶像当前资料的唯一约束；任一字段不同即可与其他偶像共存。新建偶像时若三元组完全相同 SHALL 拒绝创建；编辑偶像时若目标三元组已属于另一个 `idols.id` SHALL 拒绝提交。

#### Scenario: 同名不同团视为不同偶像

- **WHEN** 已存在偶像 `(雪梨, 紫色, 心率研究所)`,用户新建 `(雪梨, 紫色, 其他团体)`
- **THEN** 系统创建新的 `idols` 行,主界面出现两张"雪梨"卡片

#### Scenario: 三元组相同的新建请求被拒绝

- **WHEN** 用户对已存在的 `(小五, 蓝色, EAUX)` 再次通过"新建偶像" popup 填写完全相同的三元组
- **THEN** 系统 MUST 拒绝创建新偶像,并提示"该偶像已存在,请直接在卡片上加记录"

#### Scenario: 换团编辑仍是同一个偶像

- **WHEN** 用户将已有偶像 `(小五, 蓝色, EAUX)` 的团体编辑为 `新EAUX`，且目标三元组未被占用
- **THEN** 系统 SHALL 保持该偶像 `id` 和 `stable_id` 不变，并将其当前团体显示为 `新EAUX`

#### Scenario: 编辑为其他偶像当前三元组被拒绝

- **WHEN** 偶像 A 与偶像 B 已存在，用户尝试把 B 的名字、应援色、团体编辑为与 A 完全相同
- **THEN** 系统 MUST 拒绝提交，且 A、B 的资料和记录均不改变

### Requirement: 偶像字段不可原地编辑

系统 SHALL 提供对已有偶像的名字、应援色、团体的编辑入口。编辑 SHALL 更新当前 `idols` 行而不是创建新偶像；若需要"改名 / 改应援色 / 换团",用户 SHOULD 使用该编辑入口保留原有记录和统计。

#### Scenario: 偶像卡片或详情页提供编辑入口

- **WHEN** 用户查看偶像卡片或个人详情页
- **THEN** 界面 SHALL 至少在其中一处提供修改偶像名字、应援色、团体的控件

#### Scenario: 编辑偶像不改变记录归属

- **WHEN** 用户编辑某偶像的名字、应援色或团体
- **THEN** 该偶像已有 records 行的 `idol_id` SHALL 保持不变

### Requirement: 活动详情页新建偶像并附带首条本场记录

系统 SHALL 允许用户从活动详情页的新建偶像路径创建全新偶像。该路径 SHALL 要求填写偶像名字、应援色、团体, 以及首条本场切奇记录所需的数量和单价。系统 SHALL 使用当前活动的 `id`、`date` 和 `venue` 创建首条 records 行, 并在同一事务中插入 idols 行和 records 行。系统 MUST 保持当前 `(名字, 应援色, 团体)` 三元组唯一语义; 若三元组已存在, SHALL 拒绝新建偶像并提示用户改用已有偶像路径添加记录。

#### Scenario: 从活动详情新建偶像成功

- **WHEN** 用户在活动详情页选择“新建偶像”, 填写不存在的 `(名字, 应援色, 团体)` 三元组, 并填写数量和单价
- **THEN** 系统 SHALL 在同一事务中插入一条 idols 行和一条 records 行, 且 records.event_id SHALL 等于当前活动 id

#### Scenario: 新建偶像时活动字段来自当前活动

- **WHEN** 用户从活动详情页进入新建偶像路径
- **THEN** 首条记录的日期和场地 SHALL 使用当前活动的 date 和 venue, 活动关联 SHALL 使用当前活动 id, 用户不可在该路径中改为其它活动

#### Scenario: 新建偶像三元组已存在时拒绝创建

- **WHEN** 用户从活动详情页新建偶像, 但填写的 `(名字, 应援色, 团体)` 与已有偶像完全相同
- **THEN** 系统 MUST NOT 插入新的 idols 行, MUST NOT 插入首条 records 行, 并 SHALL 提示用户改用已有偶像路径添加记录

#### Scenario: 新建偶像仍必须附带首条记录

- **WHEN** 用户从活动详情页新建偶像但未填写数量或单价
- **THEN** 系统 SHALL 拒绝提交并显示校验错误, 不允许产生无 records 的空偶像

## ADDED Requirements

### Requirement: 偶像 stable_id

系统 SHALL 为每个 `idols` 行持久化一个 `stable_id` 字段。`stable_id` MUST 非空且在本地数据库中唯一。系统 MUST NOT 使用 SQLite 自增 `id` 作为 CSV 对外身份；新建偶像时 SHALL 生成新的 `stable_id`，升级既有数据库时 SHALL 为每个已有偶像回填新的 `stable_id`。

#### Scenario: 新建偶像生成 stable_id

- **WHEN** 用户新建一个不存在的偶像并提交首条切奇记录
- **THEN** 新增 `idols` 行 SHALL 包含非空且唯一的 `stable_id`

#### Scenario: 升级旧数据库回填 stable_id

- **WHEN** 用户从没有 `stable_id` 字段的旧数据库覆盖安装升级到新版本
- **THEN** 系统 SHALL 为所有既有 `idols` 行回填非空且唯一的 `stable_id`，并保持原 `id` 与 `records.idol_id` 不变

#### Scenario: 编辑偶像不改变 stable_id

- **WHEN** 用户修改某偶像的名字、应援色或团体
- **THEN** 该偶像的 `stable_id` SHALL 保持不变
