## 1. Data Layer

- [x] 1.1 Add `IdolRepository.getByGroupWithAggregates({required String groupName, String sortBy = 'count', String? year})` using parameterized SQL against `idols` and `records`.
- [x] 1.2 Ensure the query returns `Idol` rows with `id`, `name`, `color`, `group_name`, `created_at`, `total_count`, and `total_amount`, excluding idols with no records in the selected year.
- [x] 1.3 Update `IdolRepository.getGroupAggregates({String? year})` so group overview totals and idol counts are filtered by `records.date` year when provided.

## 2. Navigation and UI

- [x] 2.1 Update `GroupOverviewPage` to load years via `RecordRepository.getDistinctYears()` and show a year dropdown with "全部" plus actual years.
- [x] 2.2 In `GroupDetailPage`, load years via `RecordRepository.getDistinctYears()` and load group idols via the new repository method.
- [x] 2.3 Update `GroupOverviewPage` so changing the selected year reloads group aggregates and hides groups without records in that year.
- [x] 2.4 Add `GroupDetailPage` under `cheki_counter/lib/features/statistics/` with AppBar title set to the selected group name and an optional initial year.
- [x] 2.5 In `GroupDetailPage`, load years via `RecordRepository.getDistinctYears()` and load group idols via the new repository method.
- [x] 2.6 Add a top summary area showing current filtered idol count, total count, and total amount.
- [x] 2.7 Add a year dropdown with "全部" plus actual years, initialized from the overview page selection, and refresh data when the selection changes.
- [x] 2.8 Add "按切数 / 按金额" `ChoiceChip` controls and refresh data when the mode changes.
- [x] 2.9 Render the filtered group idol list with idol name, support color indicator, total count, and total amount.
- [x] 2.10 Show an empty state when the selected year has no records for the current group.
- [x] 2.11 Wire each idol row to navigate to the existing `/idol-detail` route with the row's idol id, name, and color.
- [x] 2.12 Update `GroupOverviewPage` so each group item opens `GroupDetailPage` and passes the current selected year.

## 3. Verification

- [x] 3.1 Add or update widget/data tests covering group overview year filtering, group detail aggregation, inherited year filtering, and count/amount sorting.
- [x] 3.2 Run `flutter analyze` in `cheki_counter`.
- [ ] 3.3 Run `flutter test` in `cheki_counter`.
