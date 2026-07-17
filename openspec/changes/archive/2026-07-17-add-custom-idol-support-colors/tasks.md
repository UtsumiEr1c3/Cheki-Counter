## 1. 依赖、颜色工具与数据库

- [x] 1.1 在 `cheki_counter/pubspec.yaml` 加入兼容当前 Flutter SDK 的调色盘依赖并完成依赖解析
- [x] 1.2 在 `cheki_counter/lib/shared/colors.dart` 增加固定灰色、名称到 ARGB、ARGB 到 `Color`、`#RRGGBB` 解析与格式化纯函数
- [x] 1.3 在 `cheki_counter/lib/data/db.dart` 将数据库升级到下一版本，为新库创建 `idols.color_value`，并为旧库按预设名称或固定灰色回填
- [x] 1.4 在 `cheki_counter/lib/data/models/idol.dart` 为 `Idol` 增加必需的 `colorValue`，同步更新构造、映射与复制逻辑

## 2. 数据访问与 CSV 传播

- [x] 2.1 在 `cheki_counter/lib/data/idol_repository.dart` 的查询投影、插入、重复检查后的更新路径中传递 `color_value`，并让 `updateCurrentProfile` 同时更新名称与色值
- [x] 2.2 在 `cheki_counter/lib/features/events/event_cheki_entry_service.dart` 的活动内新建偶像服务中接收并持久化 `colorValue`
- [x] 2.3 在 `cheki_counter/lib/data/record_repository.dart` 的活动记录 JOIN 中返回 `idol_color_value`
- [x] 2.4 在 `cheki_counter/lib/data/csv_service.dart` 将导出扩展为末尾 `应援色值` 第 16 列，并按表头兼容解析 9 至 16 列、合法 hex、缺失值和非法值

## 3. 共享应援色选择组件

- [x] 3.1 新建 `cheki_counter/lib/shared/widgets/idol_color_field.dart`，实现预设色网格、当前色预览、必填可编辑颜色名称和不透明 HSV 调色盘
- [x] 3.2 在 `cheki_counter/lib/features/home/add_idol_dialog.dart` 使用共享组件并将颜色名称与色值写入新偶像
- [x] 3.3 在 `cheki_counter/lib/features/events/event_cheki_dialog.dart` 使用共享组件，并将颜色名称与色值传入 `EventChekiEntryService`
- [x] 3.4 在 `cheki_counter/lib/features/idol_detail/edit_idol_dialog.dart` 使用共享组件准确回显并更新自定义颜色，移除重复的编辑色网格

## 4. 全部颜色展示改用持久化色值

- [x] 4.1 更新 `cheki_counter/lib/features/home/idol_card.dart`、`home_page.dart` 与 `add_record_dialog.dart`，让卡片、路由和锁定字段携带并渲染 `colorValue`
- [x] 4.2 更新 `cheki_counter/lib/features/idol_detail/idol_detail_page.dart`，让详情背景和图表使用持久化色值并保留浅色图表可读性处理
- [x] 4.3 更新 `cheki_counter/lib/features/events/event_card.dart`、`event_detail_page.dart` 与相关活动查询展示，使用偶像或查询返回的实际色值
- [x] 4.4 更新 `cheki_counter/lib/features/statistics/statistics_page.dart`、`group_detail_page.dart` 及其他 `colorFor` 实体调用点，确保自定义名称不再触发灰色回退

## 5. 测试与交付验证

- [x] 5.1 在 `cheki_counter/test/` 增加数据库新建与旧版本迁移测试，验证预设回填、未知名称灰色回填和身份/记录关联不变
- [x] 5.2 扩展 `cheki_counter/test/event_cheki_entry_service_test.dart`，覆盖自定义色创建、编辑、三元组冲突和活动记录查询色值
- [x] 5.3 扩展 `cheki_counter/test/widget_test.dart`，覆盖三个入口的共享选择器、颜色名称必填、编辑回显和主要展示色值
- [x] 5.4 扩展 CSV 测试，覆盖 16 列导出往返、15 列及更旧格式推导、非法 hex 灰色兜底和 `stable_id` 命中不覆盖本地颜色
- [x] 5.5 运行 Dart 格式化、`flutter analyze`、完整 `flutter test` 与 Android debug 构建，并修复本变更引入的全部问题
