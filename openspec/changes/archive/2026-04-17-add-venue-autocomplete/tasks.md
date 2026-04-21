## 1. 数据层:Repository 扩展

- [x] 1.1 在 `cheki_counter/lib/data/record_repository.dart` 新增 `Future<List<String>> getDistinctVenues()`:用 `SELECT venue, MAX(created_at) AS last_used FROM records WHERE venue IS NOT NULL AND venue != '' GROUP BY LOWER(venue) ORDER BY last_used DESC` 折叠大小写重复,返回每组的 venue 原文字符串列表
- [x] 1.2 在同一个文件新增 `Future<String?> canonicalVenueFor(String input)`:先 `input.trim()`,若为空返回 null;否则查 `SELECT venue FROM records WHERE LOWER(venue) = LOWER(?) ORDER BY created_at DESC LIMIT 1`,有匹配返回其 venue 原文,无匹配返回 null

## 2. 共享 Widget

- [x] 2.1 新建 `cheki_counter/lib/shared/widgets/venue_field.dart`,定义 `VenueField` StatefulWidget:接收 `TextEditingController controller`、可选 `String? Function(String?)? validator`,内部持有从 `RecordRepository.getDistinctVenues()` 异步加载的 `List<String> _options`
- [x] 2.2 `VenueField` 内部使用 Flutter Material 的 `Autocomplete<String>`:`optionsBuilder` 在输入为空时返回全量 `_options`,有输入时返回 `_options.where((v) => v.toLowerCase().contains(input.toLowerCase()))`;`fieldViewBuilder` 构造与其它 `TextFormField` 视觉一致的输入框(带 `OutlineInputBorder`、labelText `'场地'`、validator)
- [x] 2.3 `VenueField` 将 `Autocomplete` 的 textEditingController 与外部传入的 `controller` 连通(通过 `TextEditingController` 共享或在 `onSelected` / `fieldViewBuilder` 回调里同步),确保外部 Form 读取的是最新文本值
- [x] 2.4 `VenueField` 在 `initState` 触发一次 `getDistinctVenues()`;加载中也允许输入(不 block),加载完毕 `setState` 更新 `_options`
- [x] 2.5 空 `_options` 时 `optionsBuilder` 返回空 Iterable,使 `Autocomplete` 不弹 overlay,行为降级为普通输入框

## 3. 接入两处 Dialog

- [x] 3.1 修改 `cheki_counter/lib/features/home/add_record_dialog.dart`:用 `VenueField(controller: _venueController, validator: ...)` 替换原来的 venue `TextFormField`(第 172-182 行附近);import 新 widget
- [x] 3.2 修改 `_submit` 方法(约第 65 行):在 `_venueController.text.trim()` 之后调用 `await _repo.canonicalVenueFor(trimmed)`,用返回的 canonical(或原 trimmed)构造 `CheckiRecord.venue`
- [x] 3.3 修改 `cheki_counter/lib/features/home/add_idol_dialog.dart`:同样替换 venue `TextFormField`(第 196-206 行附近)为 `VenueField`
- [x] 3.4 修改 `_submit` 方法(约第 55 行):用 `RecordRepository` 实例(或让 `IdolRepository.insertWithFirstRecord` 内部负责归一化,二选一)在写入前 resolve canonical venue

## 4. 验证

- [x] 4.1 在 `cheki_counter/` 目录运行 `flutter analyze`,确认无静态错误或新增 warning
- [x] 4.2 手动验证空数据场景:清空数据库或首次运行 → 打开"新建偶像" popup → 场地字段可正常输入,不弹下拉
- [x] 4.3 手动验证历史下拉:在已有数据(至少导入过 `csv/counts.csv`)的状态下打开"添加切奇记录" popup → 聚焦场地字段 → 下拉显示历史场地,最近使用的在顶部
- [x] 4.4 手动验证子串过滤:在场地字段输入 `电切` → 下拉只保留含 `电切` 的项(`武汉电切 / 北京电切 / 长沙电切` 等),不含 `电切` 的项(如 `武汉Beach No.11`)消失
- [x] 4.5 手动验证 case-insensitive 归一化:先添加一条 venue = `Beach No.11` 的记录 → 再次添加,场地字段手打 `beach no.11` → 提交后查看该条记录在详情页显示为 `Beach No.11`(canonical 未被覆盖)
- [x] 4.6 手动验证新场地创建:输入一个历史中不存在的 venue(如 `南京无忌演艺空间`)→ 提交成功 → 重新打开 popup,下拉中出现该场地

## 5. 打包

- [x] 5.1 `flutter build apk --release --split-per-abi`,验证新版本 APK 可在 Android 真机安装并完成"添加记录 + 下拉 + 归一化"端到端流程
