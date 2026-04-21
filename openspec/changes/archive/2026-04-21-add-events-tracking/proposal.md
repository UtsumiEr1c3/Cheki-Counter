## Why

当前数据模型以"偶像 + 切奇"为中心,"去了现场"这件事只能通过切奇记录间接存在 —— 去了但没切偶像的场合完全无处记录。用户希望把"偶活/现场活动"作为一等公民,既能给切奇挂上活动归属,也能单独记录"只看演出不特典"的场次,并有一个总览看自己参加过的偶活。

## What Changes

- 新增 `events` 表承载活动的独立身份(name + venue + date),同日同场地可有多场(昼/夜公演)。
- `records` 表新增可空外键 `event_id`,已有记录保持 `event_id = NULL` 零迁移,legacy 切奇仍可读可写。
- 首页右下角 `+` 改为弹出菜单:`新建偶像` / `新建活动(无偶像)`,后者创建纯打卡 event。
- 偶像卡 `+`(AddRecordDialog)新增可选的"选/建活动"字段,提交时 upsert event 并挂 `event_id`。
- 统计入口旁新增"偶活总览"入口:按演出日期降序列出所有活动,含"(未切奇)"纯打卡行,支持年份过滤。
- **BREAKING(CSV)**: 列从 9 列扩到 11 列,末尾追加 `活动名, 活动场地, 活动日期`;三类行(A: 有活动有切奇 / B: legacy 切奇 / C: 纯打卡)共存于同一文件。
- CSV 导出排序从 `created_at DESC` 改为 `COALESCE(events.date, records.date) DESC`(legacy 行同样按演出日期排)。
- Records 去重 key 追加 `event_id`,避免昼/夜公演被错误合并。
- 修掉 CSV header 老 bug:`'ID'` → `'偶像名'`。

### 不在本次范围内

- 不做"一键把老 records 聚类成 events"的补录功能。
- 不改 AddIdolDialog(新建偶像首条记录不选 event,走 legacy 路径)。
- 不做活动的编辑/删除 UI,留待后续 change。

## Capabilities

### New Capabilities
- `events`: 活动实体的创建、查询、总览展示,以及与 records 的关联语义。

### Modified Capabilities
- `records`: 加入可空 `event_id` 外键、venue fallback 显示规则、去重 key 升级。
- `csv-io`: 11 列新格式、三类行语义、导入 upsert 流程、排序变更、向后兼容读 9 列老 CSV。

## Impact

- **DB schema**: `cheki_counter.db` 从 v1 升到 v2。需要 `onUpgrade` 建表 + ALTER TABLE 加列。
- **data 层**: 新增 `EventRepository`;`RecordRepository` 去重 key、查询 JOIN、venue 历史 UNION 更新。
- **features 层**: 新增 `features/events/`(总览页、详情页、AddEventDialog);修改 `features/home/add_record_dialog.dart` 加 event 选择器;修改 `home_page.dart` 把 `+` 改为菜单;修改 `statistics_page.dart` 顶栏加入口。
- **CSV 服务**: `csv_service.dart` header、export SQL、import 解析全面改写;保留 9 列 fallback。
- **specs**: 新增 `specs/events/spec.md`;`specs/records/spec.md` 与 `specs/csv-io/spec.md` 产出增量。
- **兼容性**: 老 9 列 CSV 可被新版本导入(走 B 行路径);新版本导出的 11 列 CSV 在老版本导入会因列数检查被拒,用户需先升级。
