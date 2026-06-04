## 1. Data Layer

- [x] 1.1 Add or expose an idol lookup method in `lib/data/idol_repository.dart` for event-scoped existing-idol selection.
- [x] 1.2 Add focused repository tests or widget-backed coverage for inserting a record with the current event id, date, venue, subtotal, and `is_online = 0`.
- [x] 1.3 Add coverage that event-scoped new-idol creation inserts `idols` and the first `records` row in one transaction.

## 2. Event-Scoped Add Flow

- [x] 2.1 Create an event-scoped add dialog or sheet under `lib/features/events/` that lets users choose between existing idol and new idol paths.
- [x] 2.2 Implement the existing-idol path with idol selection, count validation, unit-price validation, and record insertion using the current event.
- [x] 2.3 Implement the new-idol path with name, color, group, count, unit-price validation, triple-duplicate handling, and first-record insertion using the current event.
- [x] 2.4 Lock or omit editable event/date/venue controls in the event-scoped flow so records cannot be attached to another event from this entry point.

## 3. Event Detail Integration

- [x] 3.1 Add an add-cheki entry point to `lib/features/events/event_detail_page.dart`.
- [x] 3.2 Launch the event-scoped add flow from `EventDetailPage` with the loaded `CheckiEvent`.
- [x] 3.3 Reload `EventDetailPage` after the dialog returns success so totals, groups, records, and empty state update immediately.
- [x] 3.4 Confirm returning to `EventsOverviewPage` still triggers its existing reload and updates event cards.

## 4. Verification

- [x] 4.1 Run `flutter analyze` for the Flutter project.
- [x] 4.2 Run the relevant Flutter tests.
- [x] 4.3 Manually verify adding an existing idol from an empty event removes the empty state and updates totals.
- [x] 4.4 Manually verify creating a new idol from an event creates the idol, attaches its first record to the current event, and rejects duplicate triples.
