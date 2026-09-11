import 'package:equatable/equatable.dart';

class CashBoxModel extends Equatable {
  final int? id;
  final String date; // YYYY-MM-DD
  final double openingBalance;
  final double cashIn;
  final double cashOut;
  final double closingBalance;
  final String? notes;

  const CashBoxModel({
    this.id,
    required this.date,
    required this.openingBalance,
    required this.cashIn,
    required this.cashOut,
    required this.closingBalance,
    this.notes,
  });

  CashBoxModel copyWith({
    int? id,
    String? date,
    double? openingBalance,
    double? cashIn,
    double? cashOut,
    double? closingBalance,
    String? notes,
  }) {
    return CashBoxModel(
      id: id ?? this.id,
      date: date ?? this.date,
      openingBalance: openingBalance ?? this.openingBalance,
      cashIn: cashIn ?? this.cashIn,
      cashOut: cashOut ?? this.cashOut,
      closingBalance: closingBalance ?? this.closingBalance,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'opening_balance': openingBalance,
      'cash_in': cashIn,
      'cash_out': cashOut,
      'closing_balance': closingBalance,
      'notes': notes,
    };
  }

  factory CashBoxModel.fromMap(Map<String, dynamic> map) {
    return CashBoxModel(
      id: map['id'] as int?,
      date: map['date'] as String? ?? '',
      openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0.0,
      cashIn: (map['cash_in'] as num?)?.toDouble() ?? 0.0,
      cashOut: (map['cash_out'] as num?)?.toDouble() ?? 0.0,
      closingBalance: (map['closing_balance'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        date,
        openingBalance,
        cashIn,
        cashOut,
        closingBalance,
        notes,
      ];
}
