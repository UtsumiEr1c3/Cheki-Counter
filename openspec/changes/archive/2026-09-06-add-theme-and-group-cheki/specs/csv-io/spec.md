## ADDED Requirements

### Requirement: CSV 保存特殊切类型
CSV SHALL 在尾部追加“切奇类型”“切奇名称”和“团切成员”。主题切行 SHALL 保存偶像与主题名称；团切行 SHALL 将偶像字段留空、在“团体”保存团体名称、保存团切成员及完整活动字段。旧 CSV 缺少新增列时 SHALL 按普通切处理。

#### Scenario: 团切往返
- **WHEN** 用户导出并重新导入一条活动团切
- **THEN** 系统恢复团体、当时成员、活动、数量和金额，且不创建虚假偶像或重复记录

#### Scenario: 导入旧 CSV
- **WHEN** CSV 没有“切奇类型”和“切奇名称”列
- **THEN** 原有记录继续按普通切导入
