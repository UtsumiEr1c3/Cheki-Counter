## Why

当前偶像应援色的自定义选择只能通过调色盘拖动完成，用户已经知道准确的 RGB 十六进制色值时无法直接录入，难以复现官方应援色或在不同设备间保持一致。现有颜色选择依赖已具备内置 Hex 输入能力，可以用很小的改动补足精确输入路径。

## What Changes

- 在共享的偶像应援色调色盘弹窗中显示内置 Hex 输入栏。
- 允许用户输入 `#RRGGBB` 形式的 RGB 十六进制颜色，并让输入结果与调色盘选中状态同步。
- 保持现有“取消/确定”提交语义、颜色名称校验和不透明 ARGB 持久化行为不变。
- 为首页新增偶像、活动详情新建偶像和编辑偶像共用的颜色组件补充 Hex 输入交互测试。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `idols`: 新增偶像的共享应援色选择器支持通过调色盘内置 Hex 输入栏精确选择颜色。
- `idol-editing`: 编辑偶像时使用的共享应援色选择器支持通过调色盘内置 Hex 输入栏精确选择颜色。

## Impact

- 受影响代码：`cheki_counter/lib/shared/widgets/idol_color_field.dart`。
- 受影响测试：`cheki_counter/test/widget_test.dart`。
- 依赖：继续使用现有 `flutter_colorpicker 1.1.0`，不新增或升级依赖。
- 数据库、数据模型、CSV 格式和外部 API 均不变。
