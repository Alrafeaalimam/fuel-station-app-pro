import 'package:equatable/equatable.dart';

class ExpenseModel extends Equatable {
  final int? id;
  final String date; // YYYY-MM-DD or ISO
  final String category; // 'كهرباء' | 'صيانة' | 'رواتب' | 'أخرى'
  final double amount;
  final String description;
  final int recordedByUserId;

  const ExpenseModel({
    this.id,
    required this.date,
    required this.category,
    required this.amount,
    required this.description,
    required this.recordedByUserId,
  });

  ExpenseModel copyWith({
    int? id,
    String? date,
    String? category,
    double? amount,
    String? description,
    int? recordedByUserId,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      date: date ?? this.date,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      recordedByUserId: recordedByUserId ?? this.recordedByUserId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'category': category,
      'amount': amount,
      'description': description,
      'recorded_by_user_id': recordedByUserId,
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] as int?,
      date: map['date'] as String? ?? DateTime.now().toIso8601String(),
      category: map['category'] as String? ?? 'أخرى',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String? ?? '',
      recordedByUserId: map['recorded_by_user_id'] as int? ?? 1,
    );
  }

  @override
  List<Object?> get props => [
        id,
        date,
        category,
        amount,
        description,
        recordedByUserId,
      ];
}
