/// PostgreSQL `date` columns travel as `yyyy-MM-dd` strings, never as
/// timestamps and never as `DateTime` objects.
library;

String dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime? parseDateOnly(Object? value) =>
    value == null ? null : DateTime.tryParse(value as String);

/// True when `value` falls inside `[start, end]`, comparing whole days so a
/// time-of-day component can never push a row out of its own period.
///
/// Accepts either form a date arrives in: a raw `yyyy-MM-dd` string straight
/// from a query, or a `DateTime` already parsed onto a model.
bool dateInRange(Object? value, DateTime start, DateTime end) {
  final day = value is DateTime
      ? DateTime(value.year, value.month, value.day)
      : parseDateOnly(value);
  if (day == null) return false;
  return !day.isBefore(DateTime(start.year, start.month, start.day)) &&
      !day.isAfter(DateTime(end.year, end.month, end.day));
}
