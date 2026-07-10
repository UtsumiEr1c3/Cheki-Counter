## 1. 数据层

- [x] 1.1 在 `cheki_counter/lib/data/db.dart` 为 `idols` 增加 `stable_id TEXT NOT NULL`，提升 DB version，并在升级时为既有 idols 回填唯一 stable id。
- [x] 1.2 在 `cheki_counter/lib/data/models/idol.dart` 增加 `stableId` 字段，并更新 `toMap` / `fromMap`。
- [x] 1.3 在 `cheki_counter/lib/data/idol_repository.dart` 增加 stable id 生成、按 stable id 查找、按 `id` 更新偶像当前资料的方法。
- [x] 1.4 在 `IdolRepository` 增加编辑冲突检查：目标 `(name, color, group_name)` 若属于其他 `idols.id`，返回可展示的重复错误。
- [x] 1.5 确认 `insertWithFirstRecord`、`findByTriple` 和旧 CSV 导入路径仍按三元组查找或创建偶像，保持当前版本兼容。

## 2. 状态与业务刷新

- [x] 2.1 在偶像列表状态管理中增加编辑成功后的刷新路径，确保主界面汇总、排序和卡片资料重新加载。
- [x] 2.2 确认偶像详情页读取记录和统计时始终通过 `records.idol_id` 关联当前 `idols` 行，不因资料编辑重写 records。
- [x] 2.3 确认添加切奇弹窗从更新后的 `Idol` 对象显示锁定的名字、应援色、团体字段。

## 3. UI

- [x] 3.1 在偶像详情页或偶像卡片增加编辑入口，入口文案使用简体中文。
- [x] 3.2 新增或复用编辑偶像弹窗/表单，预填当前名字、应援色、团体。
- [x] 3.3 实现编辑表单校验：名字非空、团体非空、应援色合法或沿用当前未知色兜底策略。
- [x] 3.4 实现三元组冲突提示：当目标资料已被其他偶像占用时，拒绝提交并显示中文错误。
- [x] 3.5 编辑成功后关闭弹窗并刷新当前页面；主界面卡片、详情页标题和卡片颜色必须显示新资料。

## 4. CSV 兼容

- [x] 4.1 修改 `cheki_counter/lib/data/csv_service.dart` 导出：新增 `偶像ID` 列，输出 `idols.stable_id` 和当前名字、应援色、团体。
- [x] 4.2 修改 CSV 导入：15 列新格式优先按 `偶像ID` / `stable_id` 定位偶像，找不到则创建带该 stable id 的偶像。
- [x] 4.3 保持旧 9/11/12/13/14 列 CSV 兼容：没有 `偶像ID` 时继续按三元组查找或创建偶像。
- [x] 4.4 验证 stable id 命中本地偶像但 CSV 资料不同的情况，只导入 records，不自动覆盖本地当前资料。

## 5. 测试与验证

- [x] 5.1 增加数据层测试：升级/新建偶像会生成 stable id，且 stable id 唯一。
- [x] 5.2 增加数据层测试：编辑偶像成功后 `id` 和 `stable_id` 不变，既有 records 的 `idol_id` 不变。
- [x] 5.3 增加数据层测试：编辑为其他偶像的完整三元组时被拒绝。
- [x] 5.4 增加导入导出测试：编辑后导出使用 stable id 和新资料，重新导入能按 stable id 识别同一个偶像。
- [x] 5.5 增加导入测试：旧 CSV 仍按三元组兼容处理。
- [x] 5.6 增加 UI/widget 测试或手动验证：编辑后主界面卡片、详情页和添加切奇弹窗显示新资料。
- [x] 5.7 运行 Flutter 测试与静态检查，确认现有添加记录、删除最后一条记录、活动详情添加记录路径不回归。
