## 1. 数据层 - Schema 与模型

- [x] 1.1 `lib/data/db.dart` 将 `version: 1` 改为 `version: 2`,新增 `_onUpgrade` 回调:`CREATE TABLE events` + `CREATE UNIQUE INDEX idx_events_triple ON events(name, venue, date)` + `ALTER TABLE records ADD COLUMN event_id INTEGER`
- [x] 1.2 `lib/data/db.dart` 将新 `events` 表与 `records.event_id` 列同步加入 `_onCreate`(首次安装走这条)
- [x] 1.3 新建 `lib/data/models/event.dart`,定义 `CheckiEvent { id, name, venue, date, createdAt }` 及 `toMap`/`fromMap`
- [x] 1.4 `lib/data/models/record.dart` 的 `CheckiRecord` 加可空字段 `int? eventId`,同步更新 `toMap`/`fromMap`(`event_id` 键)

## 2. 数据层 - Repository

- [x] 2.1 新建 `lib/data/event_repository.dart`:`upsertByTriple(name, venue, date, createdAt)`(先 SELECT 再 INSERT,返回 event.id)、`getAll()`、`getById(id)`、`getDistinctYears()`、`getAllWithRecordsSummary({year})`(返回列表含 event + 聚合 count/amount + idols summary)
- [x] 2.2 `lib/data/record_repository.dart` 的 `insert` 支持传入可选 `eventId`,写入 `event_id` 列
- [x] 2.3 `lib/data/record_repository.dart` 的 `existsByDedupKey` 签名加 `int? eventId` 参数,WHERE 子句中对 `event_id` 用 `(event_id IS NULL AND ? IS NULL) OR event_id = ?` 以支持 NULL 相等比较
- [x] 2.4 `lib/data/record_repository.dart` 新增 `getByEventId(eventId)`、`getVenueHistory()` 改为 `UNION` `records.venue` 与 `events.venue`(DISTINCT,按最近 created_at 降序)
- [x] 2.5 `lib/data/idol_repository.dart` 的查询 JOIN 路径如有依赖 `records.venue` 的显示,在返回结构中同步附带 `event.venue`(fallback 用)  _当前 idol_repository 不输出 venue,records 始终写入非空 venue,无需改动_

## 3. UI - 首页 FAB 菜单与 AddEventDialog

- [x] 3.1 `lib/features/home/home_page.dart` 将 `FloatingActionButton` 替换为 `SpeedDial` 或 `PopupMenuButton` 弹出"新建偶像"与"新建活动(无偶像)"两项
- [x] 3.2 新建 `lib/features/events/add_event_dialog.dart`,字段:活动名(必填)、场地(必填,可打字 + 历史下拉)、日期(默认今天);提交走 `EventRepository.upsertByTriple`,冲突复用
- [x] 3.3 AddEventDialog 场地字段归一化:`trim()` + UNION 查找 case-insensitive canonical

## 4. UI - AddRecordDialog 增加活动字段

- [x] 4.1 `lib/features/home/add_record_dialog.dart` 新增"活动"字段(可选),UI 为"可打字 + 历史下拉"(复用 venue 控件的风格),下拉来自 `EventRepository.getAll()`,按 name 子串 case-insensitive 过滤
- [x] 4.2 选择已有 event 时联动填充 venue 与 date 字段(用户仍可手动改)
- [x] 4.3 提交逻辑:若活动字段非空,先 `EventRepository.upsertByTriple(活动名, 当前venue, 当前date, now)` 拿到 event.id;再 `RecordRepository.insert` 传 `eventId = event.id`;整体在事务里(sqflite `db.transaction`)
- [x] 4.4 活动字段空提交时 `eventId = null`,走 legacy 路径

## 5. UI - 偶活总览与详情页

- [x] 5.1 新建 `lib/features/events/events_overview_page.dart`:AppBar + 年份下拉(复用 year-filter-hide-empty 模式) + `ListView.builder` 卡片列表
- [x] 5.2 卡片 widget 新建 `lib/features/events/event_card.dart`:渲染日期·场地 / 活动名 / 偶像摘要(`小五 ×3 · 桃子 ×2`)或"(未切奇)" / 当场小计或"—"
- [x] 5.3 总览页底部 sticky 汇总栏:`N 场 · M 场有切奇 · ¥total`
- [x] 5.4 新建 `lib/features/events/event_detail_page.dart`:活动信息头 + 按偶像分组的 records 列表;纯打卡时显示"暂无切奇记录"
- [x] 5.5 `lib/features/statistics/statistics_page.dart` 或 home_page AppBar 添加偶活总览入口 icon(放在统计 icon 旁边),点击 push `EventsOverviewPage`

## 6. CSV - 导出

- [x] 6.1 `lib/data/csv_service.dart` 的 `_header` 常量改为 11 列:`['偶像名', '应援色', '团体', '日期', '数量', '单价', '小计', '场地', '创建时间', '活动名', '活动场地', '活动日期']`
- [x] 6.2 `exportCsv` 的 SQL 改为两路 UNION:(a) records LEFT JOIN idols LEFT JOIN events(含所有 records,event 字段可空);(b) events 中无任何关联 records 的纯打卡行;外层 `ORDER BY COALESCE(e.date, r.date) DESC, ...`
- [x] 6.3 导出行构造:分别处理 records 行(偶像/切奇字段取自 records+idols,活动字段取自 event 或留空)与纯打卡 event 行(偶像/切奇字段留空,列 8 `创建时间` 取 `events.created_at`,活动字段取 event)

## 7. CSV - 导入

- [x] 7.1 `lib/data/csv_service.dart` 的 `importCsv` header 检查宽松化:列数只要 ≥ 9 即可(等于 9 走 legacy,等于 11 走新格式,其间按尾部留空处理)
- [x] 7.2 单行解析分两侧:先解析活动三字段(索引 9, 10, 11,缺列按空);若三字段全非空,按 `EventRepository.upsertByTriple` 取 event.id
- [x] 7.3 再解析记录侧(索引 0-8);若偶像必填字段全非空,按现有 idol upsert 流程 + records 插入,传入上一步 event.id(可为 null)
- [x] 7.4 调用 `existsByDedupKey` 时传入 `eventId` 新参数;NULL 相等逻辑由 repository 层 WHERE 子句保证
- [x] 7.5 两侧都空时 `errors++` 并记录"既无偶像也无活动"
- [x] 7.6 导入摘要对话框(UI 层)新增"新增活动 A 个"字段;`ImportResult` 结构体增加 `int newEvents = 0`

## 8. 归档 CSV

- [ ] 8.1 同步更新仓库根目录的 `csv/counts.csv` 或新建 `csv/cheki_export_sample.csv` 展示 11 列新格式(可选文档性工作,若不做则在 proposal 的 Impact 注明)

## 9. 手动冒烟测试

- [ ] 9.1 新鲜安装 APK,跑一遍"新建偶像 → 加切奇(不选活动)→ 新建活动 → 加切奇(选已有活动)→ 偶活总览浏览 → 详情页查看"的 golden path
- [ ] 9.2 升级路径测试:在安装 v1 版本录入数据后,覆盖安装新 APK;验证老数据 `event_id` 均为 NULL,列表与统计正常
- [ ] 9.3 CSV 往返测试:导出 11 列 CSV → 清空 DB → 导入 → 验证零增量(新增 0 条,跳过全部)
- [ ] 9.4 CSV 向后兼容:使用仓库中已有的 9 列 `csv/cheki_export.csv` 导入新版本 App,验证全部按 B 行路径导入,errors = 0
- [ ] 9.5 昼夜公演场景:新建同日同场地不同名两个 event,各加一条相同偶像/数量/单价/场地的切奇;验证两条 records 都存在未被去重

## 10. 打包与交付

- [x] 10.1 运行 `flutter pub get` 确认无依赖变动(本 change 不引入新包)
- [ ] 10.2 使用 `build-flutter-apk` skill 产出 release APK,确认体积与启动正常
