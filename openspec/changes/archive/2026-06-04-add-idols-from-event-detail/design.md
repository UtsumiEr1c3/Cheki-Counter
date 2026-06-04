## Context

Event overview cards already navigate to `EventDetailPage`, and the event detail page already reads records by `event_id` and groups them by idol. Existing record and idol creation flows can already attach records to events through `records.event_id`, and new idols are required to be created together with their first record.

The missing piece is a creation path that starts from the event detail page. In that context, the event identity is already known, so users should not need to re-select or re-type the activity name, date, or venue.

## Goals / Non-Goals

**Goals:**

- Let users add cheki records directly from the current event detail page.
- Support both existing idols and new idols in that event-scoped flow.
- Reuse the existing `idols`, `records`, and `events` data model without a schema migration.
- Keep event-scoped fields pre-filled and locked so saved records always attach to the current event.
- Refresh event detail and overview summaries after saving.

**Non-Goals:**

- No event edit or delete UI.
- No bulk record import from an event page.
- No standalone event-idol membership table.
- No changes to CSV format.
- No support for empty idols without a first record.

## Decisions

### D1. Store membership as records, not a separate event-idol table

Use `records.event_id` as the source of truth for "this event includes this idol". The event overview and detail pages already derive their idol summaries from records, so adding a separate join table would introduce duplicate state.

Why: The app's model treats idols as record-derived entities, and event summaries are also record-derived. A new join table could represent an idol attending an event without any cheki record, which is outside the requested behavior.

Alternative considered: Create `event_idols(event_id, idol_id)`. This was rejected because the requested action is "added the idol they cheki'd", which includes quantity and price and therefore naturally creates a record.

### D2. Add a two-path event-scoped add flow

The event detail page shall expose one add entry point, then let users choose either an existing idol or a new idol.

Why: Existing and new idol creation need different fields. Existing idols only need selection plus record fields, while new idols need name, color, group, and the first record fields.

Alternative considered: Reuse only `AddIdolDialog`. This would force users to create duplicate idols when the idol already exists.

### D3. Lock current event fields in event-scoped creation

When launched from an event detail page, the dialog shall use the current event's id, name, date, and venue. These fields are not editable in the event-scoped flow.

Why: The user has already chosen the event by entering its detail page. Editable event fields would allow accidental attachment to a different event while the UI still visually belongs to the original event.

Alternative considered: Pre-fill but keep fields editable. This was rejected because existing global add-record flows already cover flexible event selection.

### D4. Reuse existing insert paths where practical

For existing idols, insert a `CheckiRecord` with the selected idol id and current `event_id`. For new idols, reuse the existing transaction shape that inserts `idols` and the first `records` row together.

Why: This preserves the "no empty idols" rule and avoids schema changes. It also keeps event summaries, idol totals, and detail grouping consistent with current repository behavior.

Alternative considered: Add special event-only repository methods. This may still be useful as thin wrappers, but they should delegate to the same underlying write semantics.

## Risks / Trade-offs

- [Risk] The add flow may duplicate form logic already present in `AddRecordDialog` and `AddIdolDialog`. -> Mitigation: Extract or parameterize only the shared field behavior needed for event-scoped defaults instead of copying full dialogs.
- [Risk] Existing idol selection may become slow if the idol list grows. -> Mitigation: Use a searchable picker/autocomplete backed by a lightweight idol list query.
- [Risk] Event detail can show stale totals after saving. -> Mitigation: Always reload the event and records after the add dialog returns success; the overview already reloads after returning from detail.
- [Risk] Locking event fields reduces flexibility. -> Mitigation: Users can still use the global add-record flow when they need to attach a record to a different event.
