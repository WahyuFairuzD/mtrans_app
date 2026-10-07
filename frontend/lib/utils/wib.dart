const String kToday = 'Hari ini';

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String _two(int n) => n.toString().padLeft(2, '0');

DateTime toWib(DateTime t) => t.toUtc().add(const Duration(hours: 7));

String wibTime(DateTime t) {
  final w = toWib(t);
  return '${_two(w.hour)}:${_two(w.minute)}';
}

String wibDateLabel(DateTime t) {
  final w = toWib(t);
  final now = toWib(DateTime.now());

  if (w.year == now.year && w.month == now.month && w.day == now.day) {
    return kToday;
  }

  return '${w.day} ${_months[w.month - 1]} ${w.year}';
}