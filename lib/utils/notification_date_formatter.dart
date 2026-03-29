String formatNotificationDate(String? raw) {
  final parsed = _parseNotificationDate(raw);
  if (parsed == null) return "-";
  return _formatDateTime(parsed);
}

String formatNotificationDateOnly(String? raw) {
  final parsed = _parseNotificationDate(raw);
  if (parsed == null) return "-";
  return _formatDateOnly(parsed);
}

String formatNotificationTimeOnly(String? raw) {
  final parsed = _parseNotificationDate(raw);
  if (parsed == null) return "-";
  return _formatTimeOnly(parsed);
}

DateTime? _parseNotificationDate(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return parsed.toLocal();
}

String _formatDateTime(DateTime value) {
  return "${_twoDigits(value.day)}.${_twoDigits(value.month)}.${value.year} "
      "${_twoDigits(value.hour)}:${_twoDigits(value.minute)}";
}

String _formatDateOnly(DateTime value) {
  return "${_twoDigits(value.day)}.${_twoDigits(value.month)}.${value.year}";
}

String _formatTimeOnly(DateTime value) {
  return "${_twoDigits(value.hour)}:${_twoDigits(value.minute)}";
}

String _twoDigits(int value) => value.toString().padLeft(2, "0");
