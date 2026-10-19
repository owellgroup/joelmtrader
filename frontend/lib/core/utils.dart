import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

double d(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

int i(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

String money(dynamic v, {bool sign = false}) {
  final x = d(v);
  final s = NumberFormat('#,##0.00').format(x.abs());
  final prefix = x < 0 ? '-' : (sign && x > 0 ? '+' : '');
  return '$prefix\$$s';
}

String pct(dynamic v, {int digits = 1}) => '${d(v).toStringAsFixed(digits)}%';

String price(dynamic v, int digits) => d(v).toStringAsFixed(digits);

DateTime? parseTime(dynamic v) {
  if (v == null) return null;
  if (v is num) return DateTime.fromMillisecondsSinceEpoch((v * 1000).toInt(), isUtc: true).toLocal();
  return DateTime.tryParse(v.toString())?.toLocal();
}

String fmtDateTime(dynamic v) {
  final t = parseTime(v);
  return t == null ? '-' : DateFormat('dd MMM, HH:mm').format(t);
}

String fmtTime(dynamic v) {
  final t = parseTime(v);
  return t == null ? '-' : DateFormat('HH:mm:ss').format(t);
}

String fmtDuration(dynamic from, dynamic to) {
  final a = parseTime(from), b = parseTime(to);
  if (a == null || b == null) return '-';
  final diff = b.difference(a);
  if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ${diff.inSeconds % 60}s';
  return '${diff.inSeconds}s';
}

class Palette {
  static const brand = Color(0xFF0000FF);
  static const brandDark = Color(0xFF0000CC);
  static const gold = Color(0xFFF59E0B);
  static const green = Color(0xFF059669);
  static const red = Color(0xFFDC2626);
  static const blue = Color(0xFF0000FF);
  static const slate = Color(0xFF64748B);
}

extension Ctx on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get cardColor2 => isDark ? const Color(0xFF12182B) : Colors.white;
  Color get borderColor => isDark ? const Color(0xFF243049) : const Color(0xFFE6E9F5);
  Color get bgColor => isDark ? const Color(0xFF070B16) : const Color(0xFFF4F6FF);
  Color get muted => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get textColor => isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
  Color pnl(dynamic v) {
    final x = d(v);
    if (x > 0) return isDark ? const Color(0xFF34D399) : Palette.green;
    if (x < 0) return isDark ? const Color(0xFFF87171) : Palette.red;
    return muted;
  }

  void toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(this).clearSnackBars();
    ScaffoldMessenger.of(this).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Palette.red : Palette.brandDark,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: error ? 5 : 3),
    ));
  }
}
