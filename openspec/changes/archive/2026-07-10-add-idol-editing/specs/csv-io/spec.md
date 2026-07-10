## ADDED Requirements

### Requirement: CSV 导出使用 stable_id 与偶像当前资料

系统 SHALL 在 CSV 导出时使用 `records.idol_id` JOIN 当前 `idols` 行，并输出该偶像的 `stable_id` 以及当前名字、应援色和团体。新版 CSV 表头 SHALL 在现有列之前新增 `偶像ID` 列，形成 15 列格式：`偶像ID,偶像名,应援色,团体,日期,数量,单价,小计,场地,创建时间,活动名,活动场地,活动日期,电切,门票价格`。若偶像资料曾被编辑，导出文件 SHALL 反映编辑后的当前资料，而不是编辑前的旧资料。

#### Scenario: 编辑后导出使用新团体

- **WHEN** 用户将偶像团体从 `旧团` 编辑为 `新团` 后导出 CSV
- **THEN** 该偶像所有导出 records 行的 `偶像ID` 列 SHALL 为该偶像的 `stable_id`，`团体` 列 SHALL 为 `新团`

#### Scenario: 导出列格式为 15 列

- **WHEN** 用户在支持偶像编辑的版本中导出 CSV
- **THEN** CSV 表头 SHALL 为 15 列，第一列为 `偶像ID`，其后保留原有 14 列顺序

### Requirement: CSV 导入优先按 stable_id 定位偶像

系统 SHALL 在 CSV 导入时识别新版 15 列格式的 `偶像ID` 列。若行内 `偶像ID` 非空，系统 SHALL 优先按 `stable_id` 定位现有偶像；若找到，SHALL 复用该 `idols.id` 并插入或去重 records；若找不到，SHALL 使用该 `stable_id` 与行内当前资料创建新偶像。若 `偶像ID` 为空或文件为旧格式，系统 SHALL 回退到 `(偶像名, 应援色, 团体)` 三元组定位或创建偶像。导入流程 MUST NOT 基于相似名字、旧名字、同色或同团进行自动合并。

#### Scenario: 导入当前三元组复用编辑后的偶像

- **WHEN** 本地存在已编辑后的偶像 `(小伍, 蓝色, 新EAUX)`，旧 CSV 行也使用 `(小伍, 蓝色, 新EAUX)` 且没有 `偶像ID`
- **THEN** 导入 SHALL 复用该偶像的 `idols.id` 并追加或去重 records

#### Scenario: 导入 stable_id 复用改资料后的偶像

- **WHEN** 本地偶像已从 `(小五, 蓝色, EAUX)` 编辑为 `(小伍, 红色, 新EAUX)`，CSV 行包含该偶像的 `stable_id`
- **THEN** 导入 SHALL 复用该偶像的 `idols.id`，即使 CSV 行中的名字、应援色或团体与本地当前资料不同

#### Scenario: stable_id 命中时不覆盖本地当前资料

- **WHEN** 本地偶像当前资料为 `(小伍, 红色, 新EAUX)`，用户导入一行同 `stable_id` 但资料为 `(小五, 蓝色, EAUX)` 的 CSV
- **THEN** 系统 SHALL 将 records 导入本地该偶像，且 SHALL NOT 把本地偶像资料改回 `(小五, 蓝色, EAUX)`

#### Scenario: 导入旧三元组不会自动合并

- **WHEN** 本地偶像已从 `(小五, 蓝色, EAUX)` 编辑为 `(小伍, 蓝色, 新EAUX)`，用户导入一份仍写着 `(小五, 蓝色, EAUX)` 的旧 CSV
- **THEN** 导入 SHALL 按兼容规则创建或复用旧三元组对应的偶像，MUST NOT 自动猜测它与 `(小伍, 蓝色, 新EAUX)` 是同一人

#### Scenario: 导入导出列数兼容旧版本

- **WHEN** 用户导入 9/11/12/13/14 列旧 CSV
- **THEN** 系统 SHALL 保持当前列数路由和字段默认值规则，并在偶像侧按导入行中的三元组定位或创建偶像
