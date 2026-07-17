## ADDED Requirements

### Requirement: CSV 应援色值解析与保真

系统 SHALL 在新版 CSV 的 `应援色值` 列使用大写 `#RRGGBB` 表示不透明实际色值。导入创建新偶像时，若该列存在且合法，SHALL 使用该值；若缺列或为空，SHALL 按应援色名称从预设表推导，无法推导时使用固定灰色。若值格式非法，系统 SHALL 记录该行错误明细、使用固定灰色继续处理该行的其他有效数据。若 `stable_id` 命中本地已有偶像，系统 SHALL 沿用现有规则保留本地当前颜色名称与色值，不用 CSV 资料覆盖。

#### Scenario: 新版 CSV 在新设备保真恢复自定义色

- **WHEN** 用户导入一行新偶像数据，应援色名称为 `星空蓝`、`应援色值` 为 `#3478F6`
- **THEN** 系统 SHALL 创建颜色名称为 `星空蓝`、实际色值为不透明 `#3478F6` 的偶像

#### Scenario: 旧 CSV 按预设名称推导色值

- **WHEN** 用户导入没有 `应援色值` 列的旧 CSV，行内应援色名称为 `蓝色`
- **THEN** 系统 SHALL 使用当前 `蓝色` 预设对应的 ARGB 色值创建偶像

#### Scenario: 旧 CSV 未知色名使用灰色

- **WHEN** 用户导入没有 `应援色值` 列的旧 CSV，行内应援色名称为 `星空蓝` 且不在预设表
- **THEN** 系统 SHALL 保留名称 `星空蓝`、使用固定灰色创建偶像，并在导入明细中提示无法恢复真实色值

#### Scenario: 非法应援色值按灰色继续导入

- **WHEN** 新版 CSV 行的 `应援色值` 为 `blue`、`#12345` 或其他非 `#RRGGBB` 文本，而其余记录字段有效
- **THEN** 系统 SHALL 使用固定灰色继续导入该行，并增加错误计数及记录行号和原因

#### Scenario: stable_id 命中时不覆盖本地色值

- **WHEN** 本地偶像的实际色值为 `#112233`，导入行使用相同 `stable_id` 但携带 `#3478F6`
- **THEN** 系统 SHALL 将 records 归入本地偶像，并保持本地实际色值 `#112233` 不变

## MODIFIED Requirements

### Requirement: CSV 列格式

系统 SHALL 使用当前固定 16 列顺序读写 CSV：`偶像ID,偶像名,应援色,团体,日期,数量,单价,小计,场地,创建时间,活动名,活动场地,活动日期,电切,门票价格,应援色值`。CSV 文件 SHALL 使用 UTF-8 编码并写入 BOM；SHALL 遵循 RFC 4180 对逗号、双引号、换行的转义。第 14 列 `电切` 值 SHALL 为 `'0'` 或 `'1'`；第 15 列 `门票价格` SHALL 为空或非负整数字符串；第 16 列 `应援色值` 在 records 行 SHALL 为 `#RRGGBB`，纯打卡活动行 SHALL 留空。

CSV 行按偶像和活动字段空/非空继续表达三类语义：有活动有切奇、无活动的 legacy 切奇、无切奇的纯打卡活动。新增的 `偶像ID` 与 `应援色值` 不改变三类行的记录和活动判定规则。

#### Scenario: 导出文件可被 Excel 正确打开

- **WHEN** 用户导出 CSV 并用 Excel 打开
- **THEN** 中文列名和中文字段值不乱码、列对齐，表头第一列为 `偶像ID`，最后一列为 `应援色值`

#### Scenario: 字段包含逗号时用双引号包裹

- **WHEN** 场地字段为 `不晚Intime, 车里子店`
- **THEN** 导出的该字段为 `"不晚Intime, 车里子店"`,导入时能恢复原值

#### Scenario: 三类行在同一文件共存

- **WHEN** 用户的 DB 同时包含有活动的新切奇、legacy 切奇和纯打卡活动
- **THEN** 导出的 CSV 文件 SHALL 同时含三类行，records 行带实际 `应援色值`，纯打卡活动行该列为空

#### Scenario: 电切记录导出为 1

- **WHEN** DB 中某条 record `is_online = 1`
- **THEN** 导出 CSV 对应行第 14 列 SHALL 为 `'1'`

#### Scenario: 活动门票价格导出

- **WHEN** DB 中某条 record 关联的 event `ticket_price = 180`
- **THEN** 导出 CSV 对应行第 15 列 SHALL 为 `'180'`

### Requirement: CSV 导出

系统 SHALL 提供 CSV 导出功能。导出 SHALL 包含当前数据库中全部 `records` 及全部没有关联 records 的 `events`。导出行按演出日期降序排列；同日 tie-break 继续使用 `records.id ASC` 或 `events.id ASC`。records 行的偶像侧字段 SHALL 来自 `records` JOIN 当前 `idols`，并包含 `stable_id`、当前名字、当前应援色名称、当前团体及由持久化 ARGB 格式化得到的 `#RRGGBB`。有活动 records 与纯打卡活动的活动侧字段、门票价格及电切值继续遵循现有规则；纯打卡活动的 `应援色值` SHALL 留空。

#### Scenario: 导出后再导入产生零增量

- **WHEN** 用户导出 CSV 随后立即再次导入同一份文件
- **THEN** 导入摘要 SHALL 显示没有新增偶像、活动或记录，既有 records 行均被去重跳过且错误为 0

#### Scenario: 导出按演出日期排序

- **WHEN** DB 中有三条 records,演出日期分别为 2026-04-19、2026-03-15、2025-12-31
- **THEN** 导出 CSV 按此顺序从上到下

#### Scenario: 纯打卡活动不输出应援色值

- **WHEN** DB 中有一个没有关联 records 的 event
- **THEN** 导出的纯打卡活动行 SHALL 在第 16 列留空

#### Scenario: 自定义应援色按 hex 导出

- **WHEN** 某 records 关联偶像的持久化色值对应 `#3478F6`
- **THEN** 导出 CSV 对应行第 16 列 SHALL 为 `#3478F6`

#### Scenario: 导出通过系统分享面板

- **WHEN** 用户在设置页点击“导出 CSV”
- **THEN** 系统调用 Android 分享面板,让用户选择保存位置或发送到其他 App;系统不硬编码保存路径

### Requirement: 向后兼容 - 读 9/11/12 列老 CSV

系统 SHALL 继续支持导入 9、11、12、13、14 和 15 列旧 CSV，并支持当前 16 列格式。旧格式 SHALL 保持既有活动、电切、门票价格和 `stable_id` 路由；所有没有 `应援色值` 列的格式 SHALL 按应援色名称推导实际色值。16 列格式 SHALL 保持前 15 列位置与旧 15 列格式完全相同，仅从末尾读取 `应援色值`。

#### Scenario: 导入 9 列 legacy CSV

- **WHEN** 用户导入一个 9 列、首列 header 为 `ID` 的老 CSV 文件
- **THEN** 系统 NOT 报列数不足，按原有 B 行规则导入，并根据应援色名称推导色值

#### Scenario: 导入 12 列 CSV

- **WHEN** 用户导入上一版本的 12 列 CSV
- **THEN** records 的 `is_online`、event 门票价格继续使用原有默认值，偶像色值按名称推导

#### Scenario: 导入当前 15 列 CSV

- **WHEN** 用户导入包含 `偶像ID` 但没有 `应援色值` 的 15 列 CSV
- **THEN** 系统 SHALL 按 `stable_id` 规则定位偶像，并在创建新偶像时按应援色名称推导色值

#### Scenario: 导入新版 16 列 CSV

- **WHEN** 用户导入表头末尾为 `应援色值` 的 16 列 CSV
- **THEN** 系统 SHALL 保持前 15 列原有解析语义，并解析第 16 列恢复实际色值

#### Scenario: 混合列数的 CSV 逐行判定

- **WHEN** 16 列 CSV 中某些数据行缺少末尾 `应援色值`
- **THEN** 系统 SHALL 将该行视为色值为空并按名称推导，不得使已有字段错位

### Requirement: CSV 导出使用 stable_id 与偶像当前资料

系统 SHALL 在 CSV 导出时使用 `records.idol_id` JOIN 当前 `idols` 行，并输出该偶像的 `stable_id`、当前名字、应援色名称、团体和实际色值。新版 CSV SHALL 在现有 15 列之后追加 `应援色值`，形成 16 列格式：`偶像ID,偶像名,应援色,团体,日期,数量,单价,小计,场地,创建时间,活动名,活动场地,活动日期,电切,门票价格,应援色值`。若偶像资料曾被编辑，导出文件 SHALL 反映编辑后的当前资料，而不是编辑前的旧资料。

#### Scenario: 编辑后导出使用新颜色资料

- **WHEN** 用户将偶像应援色名称改为 `星空蓝`、实际色值改为 `#3478F6` 后导出 CSV
- **THEN** 该偶像所有导出 records 行 SHALL 保持同一 `偶像ID`，`应援色` 为 `星空蓝`，`应援色值` 为 `#3478F6`

#### Scenario: 导出列格式为 16 列

- **WHEN** 用户在支持自定义应援色的版本中导出 CSV
- **THEN** CSV 表头 SHALL 为 16 列，前 15 列顺序不变，第 16 列为 `应援色值`

### Requirement: CSV 导入优先按 stable_id 定位偶像

系统 SHALL 在 CSV 导入时识别带 `偶像ID` 的 15 或 16 列格式。若行内 `偶像ID` 非空，系统 SHALL 优先按 `stable_id` 定位现有偶像；若找到，SHALL 复用该 `idols.id` 并插入或去重 records，且 SHALL NOT 用 CSV 中的名字、应援色名称、实际色值或团体覆盖本地当前资料；若找不到，SHALL 使用该 `stable_id` 与行内当前资料创建新偶像。若 `偶像ID` 为空或文件为旧格式，系统 SHALL 回退到 `(偶像名, 应援色名称, 团体)` 三元组定位或创建偶像。导入流程 MUST NOT 基于相似名字、相似色值、旧名字、同色或同团进行自动合并。

#### Scenario: 导入当前三元组复用编辑后的偶像

- **WHEN** 本地存在已编辑后的偶像 `(小伍, 星空蓝, 新EAUX)`，无 `偶像ID` 的 CSV 行使用相同三元组
- **THEN** 导入 SHALL 复用该偶像的 `idols.id` 并追加或去重 records

#### Scenario: 导入 stable_id 复用改资料后的偶像

- **WHEN** 本地偶像资料已经修改，CSV 行包含该偶像的 `stable_id`
- **THEN** 导入 SHALL 复用本地 `idols.id`，即使 CSV 行中的名字、应援色名称、实际色值或团体不同

#### Scenario: stable_id 命中时不覆盖本地当前资料

- **WHEN** 本地偶像实际色值为 `#112233`，用户导入一行同 `stable_id` 但色值为 `#3478F6` 的 CSV
- **THEN** 系统 SHALL 导入 records，且 SHALL NOT 修改本地偶像的颜色名称或实际色值

#### Scenario: 新 stable_id 创建并保留自定义色

- **WHEN** 16 列 CSV 行的 `stable_id` 本地不存在，颜色名称为 `星空蓝` 且色值为 `#3478F6`
- **THEN** 系统 SHALL 使用该 `stable_id`、名称和实际色值创建新偶像

#### Scenario: 导入导出列数兼容旧版本

- **WHEN** 用户导入 9/11/12/13/14/15 列旧 CSV
- **THEN** 系统 SHALL 保持原有字段默认值和定位规则，并按名称推导新偶像的实际色值
