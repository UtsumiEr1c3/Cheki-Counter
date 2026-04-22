## 1. 数据层 - Schema 与模型

- [x] 1.1 `lib/data/db.dart` 将 `version` 从 2 改为 3,`_onUpgrade` 增加 `oldVersion < 3` 分支:`ALTER TABLE records ADD COLUMN is_online INTEGER NOT NULL DEFAULT 0` + `UPDATE records SET is_online = 1 WHERE LOWER(venue) LIKE '%电切%' OR LOWER(venue) LIKE '%電切%'`
- [x] 1.2 `lib/data/db.dart` 的 `_onCreate` 在 records 表定义中加入 `is_online INTEGER NOT NULL DEFAULT 0`(首次安装走这条)
- [x] 1.3 `lib/data/models/record.dart` 的 `CheckiRecord` 加 `bool isOnline` 字段,`toMap` 写 `'is_online': isOnline ? 1 : 0`,`fromMap` 读 `(map['is_online'] as int?) == 1`(兼容旧行 NULL)

## 2. 数据层 - Repository

- [x] 2.1 `lib/data/record_repository.dart` 的 `insert` 不需要改(`record.toMap()` 已带 `is_online`)—— 只需确认 `CheckiRecord` 构造点全都传了 `isOnline`
- [x] 2.2 `lib/data/record_repository.dart` 的 `existsByDedupKey` 新增 `required bool isOnline` 参数,WHERE 子句追加 `AND is_online = ?`
- [x] 2.3 `lib/data/record_repository.dart` 的 `listByIdol` 改为 `rawQuery` LEFT JOIN `events`,返回结构改成 `List<IdolRecordRow>`(新 class,含 `CheckiRecord record` + `String? eventName`);调用方 `IdolDetailPage` 同步适配
- [x] 2.4 `lib/data/event_repository.dart` 的 `getAllWithRecordsSummary` SQL 修改:LEFT JOIN 子句加 `AND r.is_online = 0`(只聚合现场);外层 WHERE 加 `AND NOT EXISTS (SELECT 1 FROM records WHERE event_id = e.id AND is_online = 1)`
- [x] 2.5 `lib/data/event_repository.dart` 的 `getDistinctYears` 考虑是否也要过滤:由于 events 表本身有日期,且被过滤掉的 events 年份可能仍因其它 event 保留,这个方法维持原样(events 表里所有年份都能看到)—— 但 overview 显示时按过滤后结果聚合

## 3. UI - AddRecordDialog 电切开关

- [x] 3.1 `lib/features/home/add_record_dialog.dart` 顶部加 `SwitchListTile` 或 `Row` + `Switch`,label "电切",state `_isOnline` 默认 false
- [x] 3.2 开关切换回调:ON 时 `_venueController.text = '电切'` 并设置 `_venueLocked = true`;OFF 时 `_venueController.text = ''` 并 `_venueLocked = false`
- [x] 3.3 场地字段根据 `_venueLocked` 动态禁用输入(`enabled: !_venueLocked`)并隐藏下拉(或保留下拉但用户看到已锁定不可改)
- [x] 3.4 `_submit` 构造 `CheckiRecord` 时传入 `isOnline: _isOnline`
- [x] 3.5 若开关 ON 状态下用户想改场地,点击场地字段时不响应或给 snackbar 提示 "关闭电切开关后可编辑场地"(选其一,优先"不响应")

## 4. UI - IdolDetailPage 活动名显示

- [x] 4.1 `lib/features/idol_detail/idol_detail_page.dart` 的 `_records` 类型从 `List<CheckiRecord>` 改为 `List<IdolRecordRow>`;`_load()` 适配
- [x] 4.2 `ListView.builder` 的 `itemBuilder` 改 `subtitle`:若 `row.eventName != null && row.eventName!.isNotEmpty`,subtitle 为 `Column(crossAxisAlignment: start, children: [Text(eventName), Text('$venue · 单价¥$unitPrice')])`;否则保持原单行 Text
- [x] 4.3 `_totalCount` / `_totalAmount` / 图表聚合逻辑确认:仍然遍历所有记录(含电切),因为这是小偶像视角的"留了多少切 / 花了多少钱",电切也应计入
- [x] 4.4 图表(daily/monthly)也不过滤 is_online,维持当前行为

## 5. CSV - 导入导出

- [x] 5.1 `lib/data/csv_service.dart` 的 `_header` 改为 13 列:末尾追加 `'电切'`
- [x] 5.2 `exportCsv` 的 SQL 加 `r.is_online` 字段;行构造时追加列值 `record.is_online == 1 ? '1' : '0'`;纯打卡 event 行(C 行)该列输出 `'0'`
- [x] 5.3 `importCsv` 列数路由:13 列时读第 13 列 `is_online` 解析为 0/1(其它值按 0 兜底并计入 errors 日志但不中断);11/12/9 列时 `is_online` 默认 0
- [x] 5.4 `importCsv` 调用 `existsByDedupKey` 时传入 `isOnline` 参数
- [x] 5.5 `importCsv` 构造 `CheckiRecord` 时传入 `isOnline`

## 6. 归一化场地字段 - 电切 canonical

- [x] 6.1 `lib/data/record_repository.dart` 的 `canonicalVenueFor('电切')` 在历史有 `电切` 记录时会返回 `'电切'`,零改动可复用;确认 AddRecordDialog 开关 ON 时走同一路径(调用 `canonicalVenueFor('电切') ?? '电切'`)

## 6B. AddIdolDialog 同步字段(追加需求)

- [x] 6B.1 `lib/features/home/add_idol_dialog.dart` 顶部"首条切奇记录"区域新增"电切"`SwitchListTile`,state `_isOnline` 默认 false;行为与 `AddRecordDialog` 一致(ON 时 `canonicalVenueFor('电切') ?? '电切'` 锁定场地、禁用编辑,OFF 时清空 + 解锁)
- [x] 6B.2 `lib/features/home/add_idol_dialog.dart` 在场地字段下方新增 `EventField`(可选);`onEventSelected` 回调回填日期,若 `_isOnline` 为 false 则同时回填场地
- [x] 6B.3 `_submit` 若活动名非空,先调用 `EventRepository.upsertByTriple(活动名, canonicalVenue, dateStr, nowIso)` 取 `eventId`;构造 `CheckiRecord` 时写入 `eventId` 与 `isOnline: _isOnline`,再走 `IdolRepository.insertWithFirstRecord`

## 7. 手动冒烟测试

- [ ] 7.1 新鲜安装 APK:加普通切奇 → 加电切切奇 → 总览里看不到电切那场 event(若有活动名)/看得到普通场 ✓
- [ ] 7.2 升级路径:v2 旧数据装新 APK,验证 `venue = '电切'` 的历史记录自动带上 is_online=1,总览里被过滤掉
- [ ] 7.3 CSV 往返:导出 13 列 → 清空 DB → 导入 → 零增量,且 is_online 全部保持
- [ ] 7.4 CSV 向后兼容:用之前 12 列 CSV 导入,所有记录 is_online = 0(包括原来 venue='电切' 的 —— 这一步由用户的下一次应用内操作或二次迁移处理,但不会报错)
- [ ] 7.5 小偶像详情页:有活动的记录两行 subtitle 正确显示;无活动的记录维持单行

## 8. 打包

- [x] 8.1 `flutter pub get` 确认无依赖变动
- [x] 8.2 使用 `build-flutter-apk` skill 产出 release APK
