## Why

Users can already view an event and see which idols were cheki'd there, but they cannot add those records from the event itself. This forces users to leave the event context, choose or create an idol elsewhere, and manually re-select the same event details.

## What Changes

- Add an event-detail entry point for adding cheki records to the current event.
- Support adding a record for an existing idol from the event detail page.
- Support creating a new idol from the event detail page, with its first cheki record attached to the current event.
- Pre-fill and lock the current event's name, date, venue, and event id during event-scoped creation.
- Refresh the event detail and event overview summaries after a record is added.
- No breaking changes.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `events`: Event details shall provide an add-cheki flow scoped to the current event.
- `idols`: New idol creation shall be available from an event context and still create the required first record.
- `records`: Record creation shall support an event-scoped mode that locks event fields and writes the current `event_id`.

## Impact

- Affected UI: `EventDetailPage`, existing add-record and add-idol dialog flows, and any new event-scoped selector/dialog needed for choosing existing versus new idols.
- Affected data access: `IdolRepository` may need a lightweight all-idols lookup for selection; `RecordRepository` and `IdolRepository.insertWithFirstRecord` should continue writing records with `event_id`.
- Affected summaries: event detail and overview reload after saving so totals, idol grouping, and card summaries reflect the new record.
- No database schema change is expected because `records.event_id` and the idol-with-first-record transaction already exist.
