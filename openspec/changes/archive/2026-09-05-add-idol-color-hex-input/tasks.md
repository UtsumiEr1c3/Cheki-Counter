## 1. 应援色选择界面

- [x] 1.1 在 `cheki_counter/lib/shared/widgets/idol_color_field.dart` 的 `ColorPicker` 中启用内置 Hex 输入栏，并保持关闭 Alpha 与现有草稿确认语义

## 2. 组件测试

- [x] 2.1 在 `cheki_counter/test/widget_test.dart` 中覆盖输入 `#RRGGBB`、同步草稿并点击“确定”后回调不透明 ARGB 色值
- [x] 2.2 在 `cheki_counter/test/widget_test.dart` 中确认通过 Hex 输入颜色后点击“取消”不会通知外层选择

## 3. 质量验证

- [x] 3.1 对修改的 Dart 文件执行格式化，并运行静态分析和相关 Flutter 测试
