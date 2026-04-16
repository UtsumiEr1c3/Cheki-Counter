## 1. Flutter 项目脚手架

- [x] 1.1 在仓库根创建 Flutter 应用(`flutter create --platforms=android --org com.chekicounter cheki_counter`),保留 `android/` 与 `lib/`
- [x] 1.2 在 `pubspec.yaml` 添加依赖:`sqflite`、`path_provider`、`file_picker`、`share_plus`、`fl_chart`、`csv`、`intl`、`provider`
- [x] 1.3 配置 `android/app/build.gradle` minSdk 21、目标 SDK 最新,开启 `--split-per-abi` release 构建文档写进 README
- [x] 1.4 建立 `lib/` 目录分层(`data/`、`features/`、`shared/`),搭出 `main.dart` → `app.dart` 的 MaterialApp 骨架和路由表

## 2. 数据层:SQLite + Repository

- [x] 2.1 在 `lib/data/db.dart` 打开数据库,创建两张表 `idols` 与 `records`(带 `UNIQUE(name,color,group_name)` 与 `FOREIGN KEY(idol_id)`)及 schema 版本号
- [x] 2.2 在 `lib/data/models/` 下写 `Idol` 与 `CheckiRecord` 的 dataclass(`fromMap / toMap`)
- [x] 2.3 实现 `IdolRepository`:`getAllWithAggregates({sortBy, year})`、`findByTriple`、`insertWithFirstRecord(idol, record)`
- [x] 2.4 实现 `RecordRepository`:`insert`、`deleteAndCleanupIdolIfEmpty(recordId)`(事务)、`listByIdol(idolId)`、`lastUnitPriceOf(idolId)`
- [ ] 2.5 写单元测试覆盖 2.3 和 2.4:空 repo → 新建偶像带首记录 → 加第二条记录 → 删到只剩一条 → 删最后一条偶像消失

## 3. 应援色预设与共享工具

- [x] 3.1 在 `lib/shared/colors.dart` 定义 20 种应援色预设:`{中文名 → hex}`,提供 `colorHexFor(String name)` 查询函数,未知色返回灰色
- [x] 3.2 在 `lib/shared/formatters.dart` 实现日期、金额、小计显示格式化工具(`YYYY-MM-DD`、两位小数金额)

## 4. 主界面(Home)

- [x] 4.1 实现 `HomePage` scaffold:顶部汇总栏(总切数 / 总偶像数 / 总金额),右上角设置按钮,右下角 `+` FAB
- [x] 4.2 实现 `IdolCard` widget:边框取自应援色 hex,显示名字、切数、金额,右上角 `+` 按钮
- [x] 4.3 实现排序切换控件("按切数"/"按金额"),通过 `ChangeNotifier` 驱动 `GridView.builder` 刷新
- [x] 4.4 接线 `IdolListNotifier` 到 `IdolRepository.getAllWithAggregates`,写入操作后 notifyListeners

## 5. 添加切奇记录 Popup

- [x] 5.1 实现 `AddRecordDialog`:锁定偶像名 / 应援色 / 团体,日期选择器(默认今天),数量、单价、场地输入框
- [x] 5.2 数量、单价字段校验:必须为正整数,空或非数字时显示错误
- [x] 5.3 单价默认值:打开时从 `RecordRepository.lastUnitPriceOf(idolId)` 取,取不到兜底 60
- [x] 5.4 提交时 `RecordRepository.insert`,成功后关闭 dialog 并触发 home 刷新

## 6. 新建偶像 Popup

- [x] 6.1 实现 `AddIdolDialog`:名字、应援色(20 格子选择器)、团体可编辑,同页下半部复用 5.1 的记录字段
- [x] 6.2 应援色格子:4×5 网格,点击高亮,从预设表取
- [x] 6.3 提交前校验三元组 `(name, color, group)` 是否已存在 → 已存在则拒绝并提示"请在卡片上加记录"
- [x] 6.4 提交时调用 `IdolRepository.insertWithFirstRecord`(单事务同时建 idol + 首条 record)

## 7. 偶像详情页

- [x] 7.1 实现 `IdolDetailPage` scaffold:顶部两块汇总(总切数 / 总金额),中部折线图,底部记录列表
- [x] 7.2 记录列表按 `date DESC, created_at DESC` 渲染;每行提供删除按钮
- [x] 7.3 删除按钮调用 `RecordRepository.deleteAndCleanupIdolIfEmpty`;若偶像被同时删,`Navigator.pop` 回主界面
- [x] 7.4 折线图区域:提供"按日 / 按月"切换 tab

## 8. 折线图实现(fl_chart)

- [x] 8.1 按日模式:从 `RecordRepository` 查 `date → SUM(count)`,按日期排序,用离散 spots(不补缺日,不跨缺日连线)
- [x] 8.2 按月模式:生成从最早到最新的连续月序列,缺月补 0,连续连线
- [x] 8.3 处理只有 1 条记录 / 跨度 > 1 年的边界 case,坐标轴自适应

## 9. 全局统计页

- [x] 9.1 实现 `StatisticsPage` scaffold:年份下拉(含"全部")、模式切换("按切数"/"按金额")、饼图区、排行榜列表
- [x] 9.2 年份下拉数据源:`SELECT DISTINCT strftime('%Y', date) FROM records`,加"全部"
- [x] 9.3 饼图:fl_chart `PieChart`,扇区颜色取应援色 hex,侧边列表显示名字 + 百分比
- [x] 9.4 排行榜:按金额 / 按切数两种列表,带名次、色块、数值
- [x] 9.5 年份切换 / 模式切换时,所有区域同步刷新

## 10. 团体总览页

- [x] 10.1 在 `StatisticsRepository` 或 `IdolRepository` 增加 `getGroupAggregates()`,按 `group_name` 聚合切数、金额、偶像数
- [x] 10.2 实现 `GroupOverviewPage`:列表展示每个团体的切数、金额、偶像数
- [x] 10.3 空团体自动不出现(由 SQL GROUP BY 自然保证)

## 11. CSV 导入导出

- [x] 11.1 在 `lib/data/csv_service.dart` 实现 CSV 解析:RFC 4180、支持 UTF-8 BOM、固定列顺序校验
- [x] 11.2 实现合并算法:`(name,color,group)` 查 idol → 缺则建;`(idol_id, date, count, unit_price, venue, created_at)` 去重键判断是否插入
- [x] 11.3 实现错误兜底:单行失败计入错误统计,其他行继续
- [x] 11.4 实现导出:`records` 按 `created_at DESC` 全量写出,`小计` 以两位小数字符串格式
- [x] 11.5 导入摘要对话框:显示新增偶像 / 新增记录 / 跳过 / 错误计数 + 错误行号列表

## 12. 设置页

- [x] 12.1 实现 `SettingsPage`:三个入口(导入 CSV / 导出 CSV / 团体总览)
- [x] 12.2 "导入 CSV" 接 `file_picker` 选文件 → 调 csv_service 合并 → 弹摘要
- [x] 12.3 "导出 CSV" 生成临时文件 → 调 `share_plus` 调起系统分享面板
- [x] 12.4 "团体总览" 导航到 10.2 实现的页面

## 13. 种子数据验证与打磨

- [ ] 13.1 用仓库根 `counts.csv`(67 行)走完一次导入,人工校验偶像数量、总切数、总金额与预期吻合
- [ ] 13.2 回归:添加 → 删除 → 再添加 → 导出 → 导入,验证零增量导入
- [ ] 13.3 边界检查:同名不同色 / 同名同色不同团 / 未知色名 / 场地含逗号的导入导出

## 14. 打包

- [ ] 14.1 `flutter build apk --release --split-per-abi`,验证 arm64-v8a 包可在 Android 10+ 真机安装运行
- [ ] 14.2 在 README(或设置页"关于")记录版本号与已知限制
