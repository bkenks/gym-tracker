/// Unit handling. All values are stored in kilograms in the database;
/// conversion to pounds happens at the UI boundary only.
library;

bool isImperial = false;

void setImperial(bool value) => isImperial = value;

/// Display weight for a stored kilogram value (1 decimal, trimmed).
String formatWeight(double kg, {bool? imperial}) {
  final useLb = imperial ?? isImperial;
  final value = useLb ? kg * 2.2046226218 : kg;
  final rounded = (value * 10).round() / 10;
  final s = rounded.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// Parse user-entered weight (kg or lb) into stored kilograms.
double parseWeight(String input, {bool? imperial}) {
  final useLb = imperial ?? isImperial;
  final value = double.tryParse(input.replaceAll(',', '.')) ?? 0;
  return useLb ? value / 2.2046226218 : value;
}

String weightUnitLabel({bool? imperial}) => (imperial ?? isImperial) ? 'lb' : 'kg';
