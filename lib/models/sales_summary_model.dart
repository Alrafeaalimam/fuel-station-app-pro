import 'package:equatable/equatable.dart';

class SalesSummaryModel extends Equatable {
  final int? id;
  final int shiftId;
  final double cashAmount;
  final double bankTransferAmount; // بنكك
  final double creditAmount; // آجل
  final double totalAmount;

  const SalesSummaryModel({
    this.id,
    required this.shiftId,
    required this.cashAmount,
    required this.bankTransferAmount,
    required this.creditAmount,
    required this.totalAmount,
  });

  SalesSummaryModel copyWith({
    int? id,
    int? shiftId,
    double? cashAmount,
    double? bankTransferAmount,
    double? creditAmount,
    double? totalAmount,
  }) {
    return SalesSummaryModel(
      id: id ?? this.id,
      shiftId: shiftId ?? this.shiftId,
      cashAmount: cashAmount ?? this.cashAmount,
      bankTransferAmount: bankTransferAmount ?? this.bankTransferAmount,
      creditAmount: creditAmount ?? this.creditAmount,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'shift_id': shiftId,
      'cash_amount': cashAmount,
      'bank_transfer_amount': bankTransferAmount,
      'credit_amount': creditAmount,
      'total_amount': totalAmount,
    };
  }

  factory SalesSummaryModel.fromMap(Map<String, dynamic> map) {
    return SalesSummaryModel(
      id: map['id'] as int?,
      shiftId: map['shift_id'] as int? ?? 0,
      cashAmount: (map['cash_amount'] as num?)?.toDouble() ?? 0.0,
      bankTransferAmount: (map['bank_transfer_amount'] as num?)?.toDouble() ?? 0.0,
      creditAmount: (map['credit_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        shiftId,
        cashAmount,
        bankTransferAmount,
        creditAmount,
        totalAmount,
      ];
}
