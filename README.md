# Cheki Counter

地下偶像切奇(拍立得)记录与统计的离线 Android App。在 livehouse 现场快速加一条记录,事后看饼图、折线图和排行榜。

## 是什么

- 单人使用、本地 SQLite 存储、无后端、无登录、无云同步。
- Flutter 编写,仅打包 Android APK(代码不写 Android 专有 API,保留未来跨平台空间)。
- 数据通过 CSV 导入导出做手动备份,与仓库根 `csv/counts.csv` 列格式一致。

## 主要功能

- **主界面**:卡片网格展示所有有切奇记录的偶像,卡片边框 = 应援色;顶部汇总总切数 / 总偶像数 / 总金额;支持按切数或金额排序。
- **添加记录**:卡片右上角 `+` 弹窗,只填日期、数量、单价、场地;单价默认取该偶像最近一次的值。
- **新建偶像**:右下角 `+` 弹窗,填名字 / 应援色(20 格预设色板)/ 团体,并必须同时录入第一条切奇记录(无记录的偶像不存在)。
- **个人详情页**:总切数与总金额、按日 / 按月可切换的折线图、按日期倒序的记录列表(可逐条删除)。
- **全局统计页**:应援色饼图 + 按金额 / 按切数排行,支持按自然年筛选。
- **团体总览**:每个团体的总切数、总金额与偶像数。
- **CSV 导入导出**:导入为合并追加(不清空现有数据),导出按创建时间倒序写出,UTF-8 BOM。

## 业务规则

- 偶像业务主键 = `(名字, 应援色, 团体)` 三元组。改名 / 改色 / 换团 = 新建偶像,不支持原地编辑。
- 删除仅作用于单条记录。
- 删除最后一条记录时偶像记录随之消失。
- CSV 列格式:`ID, 应援色, 团体, 日期, 数量, 单价, 小计, 场地, 创建时间`。

## 技术栈

- Flutter + Dart
- SQLite(`sqflite`)
- 状态管理:`provider`
- 图表:`fl_chart`
- 文件:`file_picker`(导入)、`share_plus`(导出)
- 其他:`csv`、`intl`、`path_provider`

## 项目结构(规划)

```
lib/
├── main.dart
├── app.dart
├── data/            # db、models、repository、csv_service
├── features/        # home / idol_detail / statistics / settings
└── shared/          # 应援色预设、格式化工具
```

## 构建

```bash
flutter pub get
flutter build apk --release --split-per-abi
```

`--split-per-abi` 可让 arm64 用户只下载 ~12MB 的包。最低支持 Android 10(minSdk 21 起,实际验证 Android 10+)。
