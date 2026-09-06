## 1. 零元切奇

- [x] 1.1 调整 `AddRecordDialog`、`AddIdolDialog`、`EventChekiDialog`、`AddThemeChekiDialog` 和 `EventGroupChekiDialog` 的单价校验与解析，保持数量为正整数并允许单价 0
- [x] 1.2 调整 `EventChekiEntryService` 的服务层单价校验，并补充普通切、活动新偶像和团切的零元测试
- [x] 1.3 调整 `CsvService` 的单价导入校验并补充零元 CSV 导入测试

## 2. 支出下钻数据与界面

- [x] 2.1 在 `RecordRepository` 增加按年份、类型或参与方式查询切奇明细的数据模型和方法
- [x] 2.2 新建统一支出切奇明细页，展示记录信息、零元金额和空态，并按记录关联跳转活动或偶像详情
- [x] 2.3 为 `EventsOverviewPage` 的六个切奇支出项接入当前年份筛选和明细页导航
- [x] 2.4 补充仓库筛选、支出入口和明细导航相关测试
- [x] 2.5 在主题切明细行以偶像名为标题、展示主题名，并补充组件测试

## 3. 规范、版本与交付

- [x] 3.1 将已确认行为同步到 `openspec/specs` 主规范并严格校验变更
- [x] 3.2 将 `pubspec.yaml` 版本升级到 `1.3.1+131`
- [x] 3.3 运行格式化、静态分析和测试，修复本次变更引入的问题
- [x] 3.4 构建 release APK 并确认产物路径与版本
- [x] 3.5 保持 `1.3.1+131` 版本重新验证并将 APK 输出到 `cheki_counter/build/app/outputs/`
