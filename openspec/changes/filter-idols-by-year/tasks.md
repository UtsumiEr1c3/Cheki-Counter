## 1. 数据层修改

- [x] 1.1 修改 `lib/data/idol_repository.dart` 的 `getAllWithAggregates` 方法：当 `year` 非空时，使用 `INNER JOIN records r ON r.idol_id = i.id WHERE strftime('%Y', r.date) = '$year'` 替代当前的 `LEFT JOIN ... AND year_filter`；`year` 为空时保持 `LEFT JOIN` 不变

## 2. 验证

- [x] 2.1 运行 `flutter analyze` 确认无静态错误
- [ ] 2.2 在模拟器上手动验证：选择某一年份后，排行榜和饼图只显示该年有记录的偶像；切回"全部"后所有偶像正常显示
