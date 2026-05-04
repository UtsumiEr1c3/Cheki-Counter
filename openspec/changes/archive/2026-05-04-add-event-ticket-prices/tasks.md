## 1. 数据库与模型

- [x] 1.1 在 `lib/data/db.dart` 将数据库版本从 3 升到 4,`_onCreate` 的 `events` 表新增 `ticket_price INTEGER NOT NULL DEFAULT 0`
- [x] 1.2 在 `lib/data/db.dart` 的 `_onUpgrade` 增加 `oldVersion < 4` 迁移,为既有 `events` 表补 `ticket_price INTEGER NOT NULL DEFAULT 0`
- [x] 1.3 在 `lib/data/models/event.dart` 为 `CheckiEvent` 增加 `ticketPrice`,更新构造函数、`toMap`、`fromMap`
- [x] 1.4 在 `lib/data/event_repository.dart` 更新所有读取/写入 `events` 的 SQL 和 map,确保 `ticket_price` 始终被携带

## 2. Repository 与汇总语义

- [x] 2.1 修改 `EventRepository.upsertByTriple` 签名,接收 `ticketPrice`,新建 event 时写入门票价
- [x] 2.2 在 `EventRepository.upsertByTriple` 实现补写规则:已存在 event 且旧 `ticket_price = 0`、新 `ticketPrice > 0` 时更新;旧值非零时不覆盖
- [x] 2.3 在 `EventWithSummary` 增加 `ticketPrice` 和 `grandAmount` 语义,保留 `totalAmount` 作为切奇总价
- [x] 2.4 更新 `getAllWithRecordsSummary` 查询,返回每场 `ticket_price`,并保持电切活动过滤与现场 records 聚合规则不变

## 3. 手动录入 UI

- [x] 3.1 在 `lib/features/events/add_event_dialog.dart` 增加门票价格输入框,校验为空或非负整数,提交时传入 `upsertByTriple`
- [x] 3.2 在 `lib/features/home/add_record_dialog.dart` 增加门票价格输入框,活动为空时忽略,活动非空时随 upsert 提交
- [x] 3.3 在 `lib/features/home/add_idol_dialog.dart` 的首条切奇记录区域增加门票价格输入框,逻辑与 AddRecordDialog 对齐
- [x] 3.4 在 `lib/shared/widgets/event_field.dart` 的 autocomplete 展示与选中回调中携带 `ticketPrice`,让 AddRecordDialog/AddIdolDialog 选中已有活动时自动填充门票
- [x] 3.5 确认电切开关 ON 时仍可填写活动和门票价格,但场地仍锁定为 canonical `电切`

## 4. 偶活总览与详情展示

- [x] 4.1 在 `lib/features/events/event_card.dart` 将金额展示改为门票价、切奇价、合计价三项;纯打卡活动显示门票与合计
- [x] 4.2 在 `lib/features/events/events_overview_page.dart` 底部汇总计算门票总价、切奇总价和合计总价,并更新文案
- [x] 4.3 在 `lib/features/events/event_detail_page.dart` 顶部展示门票价、切奇总价和合计价;纯打卡活动也显示门票与合计
- [x] 4.4 检查小屏布局,确保金额文案不会溢出;必要时使用 `Wrap` 或多行展示

## 5. CSV 导入导出

- [x] 5.1 在 `lib/data/csv_service.dart` 将 `_header` 扩展为 14 列,末尾追加 `门票价格`
- [x] 5.2 更新 CSV 导入列路由:9/11/12/13 列保持兼容且门票默认 0,14 列解析第 14 列门票价格
- [x] 5.3 在 CSV 导入活动侧调用 `upsertByTriple` 时传入门票价,并对无效门票价格记录错误后按 0 兜底
- [x] 5.4 更新 CSV 导出 SQL,records 行关联 event 时输出 `events.ticket_price`,纯打卡 event 行输出 `events.ticket_price`,legacy records 行留空
- [x] 5.5 验证导出后再导入同一 CSV 不新增 event 或 record,非零门票价保持不被覆盖

## 6. 测试与验证

- [x] 6.1 增加或更新数据层测试,覆盖 v3 到 v4 迁移后既有 events 的 `ticket_price = 0`
- [x] 6.2 增加或更新 repository 测试,覆盖 upsert 新建门票、0 补写正数、非零不覆盖三种场景
- [x] 6.3 增加或更新 CSV 测试,覆盖 13 列旧文件默认门票 0、14 列导入门票、无效门票兜底
- [x] 6.4 增加或更新 widget 测试,覆盖偶活总览底部显示门票总价、切奇总价和合计总价
- [x] 6.5 运行 `flutter test` 并修复失败

## 7. 文档与收尾

- [x] 7.1 更新根 `README.md` 的功能说明、数据结构和 CSV 列格式,注明门票价格与总览汇总规则
- [x] 7.2 更新 `cheki_counter/README.md` 中与活动总览、CSV 导入导出相关的说明
- [x] 7.3 运行 `openspec status --change add-event-ticket-prices` 确认 change apply-ready
