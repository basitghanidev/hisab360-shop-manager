import 'package:decimal/decimal.dart';

/// Utility class for precise currency handling using the Decimal package.
/// In the database, we store values as 'paisa' (int) to avoid floating-point issues.
class Money {
  final Decimal _paisa;

  Money._(this._paisa);

  /// Create Money from a double (e.g., 10.50 -> 1050 paisa)
  factory Money.fromDouble(double value) {
    return Money._((Decimal.parse(value.toString()) * Decimal.fromInt(100)).round());
  }

  /// Create Money from a string (e.g., "10.50" -> 1050 paisa)
  factory Money.fromString(String value) {
    if (value.isEmpty) return Money.zero;
    try {
      // Fix potential comma or whitespace issues from UI input
      final clean = value.replaceAll(',', '').trim();
      return Money._((Decimal.parse(clean) * Decimal.fromInt(100)).round());
    } catch (_) {
      return Money.zero;
    }
  }

  /// Create Money from raw paisa stored in the database.
  factory Money.fromPaisa(int paisa) {
    return Money._(Decimal.fromInt(paisa));
  }

  static Money get zero => Money._(Decimal.zero);

  /// Convert to double for UI display or non-critical calculations.
  double toDouble() {
    return (this._paisa / Decimal.fromInt(100)).toDouble();
  }

  /// Get the raw paisa value for database storage.
  int get paisa => this._paisa.toBigInt().toInt();

  Money operator +(Money other) => Money._(this._paisa + other._paisa);
  Money operator -(Money other) => Money._(this._paisa - other._paisa);
  Money operator *(Decimal factor) => Money._((this._paisa * factor).round());

  /// Multiply by a double (e.g. quantity) with precision.
  Money multiplyByDouble(double factor) {
    return Money._((this._paisa * Decimal.parse(factor.toString())).round());
  }

  bool get isNegative => _paisa < Decimal.zero;
  Money abs() => Money._(_paisa.abs());

  @override
  String toString() => toDouble().toStringAsFixed(2);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money && runtimeType == other.runtimeType && _paisa == other._paisa;

  @override
  int get hashCode => _paisa.hashCode;
}
