# Cheki Counter

Flutter 应用主体，当前版本为 `1.1.3+113`。Cheki Counter 是离线 Android 优先的切奇记录与偶活统计工具。

## 当前能力

- 本地 SQLite 存储偶像、活动和切奇记录
- 可在偶像详情页编辑名字、应援色和团体；编辑后仍通过稳定偶像 ID 保留历史记录与备份关联
- 活动可记录门票价格,偶活总览展示门票总价、切奇总价和合计
- 添加切奇或新建偶像首条记录时可选择/创建活动,并同步填写门票价格
- CSV 导入导出使用 15 列格式，首列为 `偶像ID`、末列为 `门票价格`；兼容旧 9/11/12/13/14 列文件
- 电切记录计入偶像统计,但关联电切记录的活动会从偶活总览隐藏

## 常用命令

```bash
flutter pub get
flutter test
flutter analyze
flutter run
flutter build apk --release
```

## 相关目录

- `lib/data/`: SQLite、模型、Repository、CSV 服务
- `lib/features/events/`: 活动新建、偶活总览、活动详情
- `lib/features/home/`: 首页、新建偶像、添加切奇记录
- `lib/features/idol_detail/`: 偶像详情、统计图表、资料编辑、记录删除
- `test/`: 当前自动化测试
