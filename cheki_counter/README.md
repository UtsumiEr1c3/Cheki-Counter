# cheki_counter

Flutter 应用主体。Cheki Counter 是离线 Android 优先的切奇记录与偶活统计工具。

## 当前能力

- 本地 SQLite 存储偶像、活动和切奇记录
- 活动可记录门票价格,偶活总览展示门票总价、切奇总价和合计
- 添加切奇或新建偶像首条记录时可选择/创建活动,并同步填写门票价格
- CSV 导入导出使用 14 列格式,末尾为 `门票价格`,并兼容旧 9/11/12/13 列文件
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
- `test/`: 当前自动化测试
