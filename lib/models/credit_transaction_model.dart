import 'package:equatable/equatable.dart';

class CreditTransactionModel extends Equatable {
  final int? id;
  final int customerId;
  final int? shiftId;
  final double amount;
  final String type; // 'charge' (مبيعات آجل / سحب) | 'payment' (سداد دفعة)
  final String transactionDate;
  final String? notes;
  final int settled; // 0 = uncollected / unpaid, 1 = settled

  const CreditTransactionModel({
    this.id,
    required this.customerId,
    this.shiftId,
    required this.amount,
    required this.type,
    required this.transactionDate,
    this.notes,
    this.settled = 0,
  });

  bool get isCharge => type == 'charge';
  bool get isPayment => type == 'payment';
  bool get isSettled => settled == 1;

  CreditTransactionModel copyWith({
    int? id,
    int? customerId,
    int? shiftId,
    double? amount,
    String? type,
    String? transactionDate,
    String? notes,
    int? settled,
  }) {
    return CreditTransactionModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      shiftId: shiftId ?? this.shiftId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      transactionDate: transactionDate ?? this.transactionDate,
      notes: notes ?? this.notes,
      settled: settled ?? this.settled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'customer_id': customerId,
      'shift_id': shiftId,
      'amount': amount,
      'type': type,
      'transaction_date': transactionDate,
      'notes': notes,
      'settled': settled,
    };
  }

  factory CreditTransactionModel.fromMap(Map<String, dynamic> map) {
    return CreditTransactionModel(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int? ?? 0,
      shiftId: map['shift_id'] as int?,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: map['type'] as String? ?? 'charge',
      transactionDate: map['transaction_date'] as String? ?? DateTime.now().toIso8601String(),
      notes: map['notes'] as String?,
      settled: map['settled'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        customerId,
        shiftId,
        amount,
        type,
        transactionDate,
        notes,
        settled,
      ];
}
