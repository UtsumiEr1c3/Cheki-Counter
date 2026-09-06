## 1. 数据层与迁移

- [x] 1.1 在 `db.dart` 将数据库升级到 v10，创建 `record_groups` 关联表、索引并迁移已有单团体团切
- [x] 1.2 扩展 `CheckiRecord` 与 `RecordRepository.insert`，在事务中写入团切主体和有序团体关联，并在删除时清理关联
- [x] 1.3 调整记录、团体候选和团体统计查询，通过 `record_groups` 读取全部团体并保持整体聚合只计算一次
- [x] 1.4 在 `IdolRepository` 增加当前登记成员与最近团切快照的合并查询

## 2. 录入、展示与 CSV

- [x] 2.1 将 `EventGroupChekiDialog` 改为多团体选择与标签展示，并合并预填各团体的历史成员
- [x] 2.2 调整 `EventChekiEntryService`、活动详情和支出明细，保存并展示联合团切的全部团体
- [x] 2.3 在 `csv_service.dart` 追加“团切团体”列，完整往返多团体并兼容旧单团体 CSV

## 3. 验证与打包

- [x] 3.1 增加 v10 迁移、历史成员预填、多团体写入、统计归属和 CSV 往返测试
- [x] 3.2 运行格式化、静态分析、完整测试和 OpenSpec 严格校验
- [x] 3.3 将 `pubspec.yaml` 版本升级为 `1.3.2+132` 并构建 release APK
