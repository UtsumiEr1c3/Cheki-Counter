# Cheki Counter

Cheki Counter 是一个用 Flutter 编写的离线记账工具，用来记录偶像切奇（cheki）相关数据，并提供活动视角、偶像视角和统计视角的汇总分析。

项目当前的核心特征是：

- 本地 SQLite 存储，无后端、无登录、无云同步
- 通过 CSV 做手动备份、迁移和合并导入
- 以 Android 使用场景为主，仓库保留了 Flutter 默认多端脚手架
- 业务重点在“偶像 / 活动 / 切奇记录”三类数据的组织与统计

## 功能概览

- 首页用卡片网格展示所有已有记录的偶像，并显示总切数、偶像数、总金额
- 支持为已有偶像追加切奇记录，单价会默认带出该偶像最近一次记录的价格
- 支持新建偶像，同时要求录入第一条切奇记录
- 支持新建活动，即使该活动暂时没有关联任何切奇记录也可以单独保存
- 偶像详情页提供总览、按日/按月折线图、历史记录列表和单条删除
- 活动总览页提供年份筛选、活动摘要、总金额汇总和活动详情页
- 统计页提供按切数/按金额的饼图与排行榜，并支持按年份过滤
- 设置页提供 CSV 导入、CSV 导出和团体总览入口
- 支持“线上 / 电切记录”标记；这类记录计入偶像统计，但会影响活动总览的展示规则

## 仓库结构

```text
.
|-- cheki_counter/          # Flutter 应用主体
|   |-- lib/
|   |   |-- main.dart       # 应用入口，初始化数据库和 Provider
|   |   |-- app.dart        # MaterialApp、路由定义
|   |   |-- data/           # SQLite、模型、仓储、CSV 服务
|   |   |-- features/       # 各业务页面与对话框
|   |   `-- shared/         # 颜色、格式化、复用输入控件
|   |-- android/            # Android 工程配置
|   |-- windows/            # Flutter 生成的 Windows 脚手架
|   `-- test/               # 测试目录，目前仅保留占位测试
|-- openspec/               # 规格说明与变更记录
|-- csv/                    # 本地样例/临时数据目录（已忽略，不应提交私有数据）
`-- UIReference/            # UI 参考资料
```

## 代码架构

### 1. 入口与状态管理

- `cheki_counter/lib/main.dart`
  - 启动时先初始化 SQLite 数据库
  - 使用 `provider` 注册 `IdolListNotifier`
- `cheki_counter/lib/app.dart`
  - 定义首页、统计页、设置页、团体总览页和偶像详情页路由

### 2. 数据层

- `data/db.dart`
  - 负责数据库创建与升级
  - 当前 schema 版本为 `3`
  - 表结构包括 `idols`、`events`、`records`
- `data/models/`
  - `idol.dart`：偶像实体与聚合字段
  - `event.dart`：活动实体
  - `record.dart`：切奇记录实体
- `data/*_repository.dart`
  - `IdolRepository`：偶像查询、聚合、新偶像和首条记录的事务写入
  - `RecordRepository`：记录写入、删除、按偶像/活动查询、场地归一化辅助、年份/场地统计
  - `EventRepository`：活动 upsert、活动列表、活动摘要聚合
- `data/csv_service.dart`
  - 负责 CSV 导入导出
  - 处理 BOM、兼容旧版列格式、去重、错误汇总和导出文件生成

### 3. UI 分层

- `features/home/`
  - 首页、偶像卡片、新建偶像、新增记录
- `features/idol_detail/`
  - 偶像详情、折线图、记录删除
- `features/events/`
  - 活动新建、活动总览、活动详情
- `features/statistics/`
  - 总体统计页、团体总览页
- `features/settings/`
  - CSV 导入导出、团体总览入口
- `shared/widgets/`
  - `VenueField`：历史场地下拉 + 输入过滤
  - `EventField`：历史活动下拉 + 自动带出日期/场地

## 数据模型与业务规则

### 偶像

- 业务唯一键是 `(name, color, group_name)`
- 同时进行改名、换色、换团体在当前实现里等价于新建一个偶像
- 偶像必须至少有一条记录；删除最后一条记录时会连带删除该偶像

### 活动

- 业务唯一键是 `(name, venue, date)`
- 活动可以独立存在，不要求必须挂接记录(即只看不特)
- 当前没有活动编辑和活动删除 UI

### 切奇记录

- 关键字段包括日期、数量、单价、小计、场地、创建时间、可选偶活名称、是否电切
- `subtotal` 按 `count * unit_price` 持久化保存
- 新建记录时：
  - 既有偶像默认继承最近一次单价
  - 新偶像默认单价为 `60`
  - 可选绑定活动
  - 可标记为电切

### 电切

- `records.is_online = 1` 表示线上记录
- 线上记录仍计入偶像详情页和全局统计
- 只要某个活动关联过任意线上记录，该活动就不会出现在活动总览页

### 场地归一化

- 手动录入场地时会做 `trim()` 和大小写归一化匹配
- 如果历史中已存在仅大小写不同的同名场地，会复用已有写法
- CSV 导入不会做这一步归一化，而是按文件原始值导入

## CSV 说明

### 导出格式

当前导出采用固定 13 列：

```text
偶像名,应援色,团体,日期,数量,单价,小计,场地,创建时间,活动名,活动场地,活动日期,电切
```

说明：

- 编码为 UTF-8 BOM，便于在 Excel 中直接打开
- 会同时导出普通记录、关联活动的记录，以及没有关联记录的纯活动行
- 导出时按演出日期倒序排列

### 导入规则

- 导入语义为“合并追加”，不会清空现有数据库
- 支持兼容旧版 9 列、11/12 列以及当前 13 列格式
- 会先尝试按活动三元组复用或创建活动，再处理记录
- 记录去重键为：

```text
(idol_id, date, count, unit_price, venue, created_at, event_id, is_online)
```

- 单行失败不会中断整体导入，最终会汇总新增、跳过和错误数

## 使用方法

### 环境准备

建议准备：

- Flutter SDK
- Android SDK / Android Studio
- 可用的 Android 模拟器或真机

先在项目应用目录安装依赖：

```bash
cd cheki_counter
flutter pub get
```

### 本地运行

```bash
cd cheki_counter
flutter run -d android
```

如果你已经连接好设备，也可以直接：

```bash
cd cheki_counter
flutter run
```

### 构建 APK

```bash
cd cheki_counter
flutter build apk --release
```

如果需要按 ABI 拆包：

```bash
cd cheki_counter
flutter build apk --release --split-per-abi
```

## 典型使用流程

1. 首次使用时，在首页右下角 `+` 新建偶像，并录入第一条记录
2. 后续可直接在偶像卡片右上角追加记录
3. 如果某次活动暂时没有切奇，也可以单独新建活动
4. 在“活动总览”查看线下活动摘要，在“统计”查看整体占比和排行
5. 在“设置”中导出 CSV 备份，或导入 CSV 合并旧数据

## 开发说明

### 技术栈

- Flutter
- Dart
- `provider`
- `sqflite`
- `fl_chart`
- `csv`
- `file_picker`
- `share_plus`
- `intl`
- `path_provider`

### 规格文档

`openspec/` 目录下保留了相对完整的需求规格，特别是这些部分与当前实现高度相关：

- `openspec/specs/records/spec.md`
- `openspec/specs/events/spec.md`
- `openspec/specs/csv-io/spec.md`
- `openspec/specs/statistics/spec.md`
- `openspec/specs/settings/spec.md`

### 测试现状

- `cheki_counter/test/widget_test.dart` 目前仍是占位测试
- 当前仓库更接近“可运行原型 + 规格驱动迭代”的状态，自动化测试还需要补齐

## 隐私与数据说明

- 项目本身不依赖在线服务，数据默认保存在本地 SQLite
- `csv/` 目录被 `.gitignore` 忽略，适合放个人导入导出文件，但不应提交真实私有数据
- README 不应记录任何个人路径、账号、设备信息、活动私密数据或样例导出内容

## 当前限制

- 没有登录、同步、多端合并冲突处理
- 没有记录编辑，只支持新增和删除
- 没有活动编辑和删除界面
- 自动化测试尚未完善
- 仓库虽然保留多平台脚手架，但当前主要使用路径和文档以 Android 为准
