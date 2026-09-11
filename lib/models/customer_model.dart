import 'package:equatable/equatable.dart';

class CustomerModel extends Equatable {
  final int? id;
  final String name;
  final String type; // 'زبون دائم' | 'مؤسسة حكومية'
  final String phone;
  final double creditLimit;
  final double currentBalance; // المبلغ المستحق عليه

  const CustomerModel({
    this.id,
    required this.name,
    required this.type,
    required this.phone,
    required this.creditLimit,
    required this.currentBalance,
  });

  bool get isGovernment => type == 'مؤسسة حكومية';
  bool get isLimitExceeded => currentBalance > creditLimit;
  double get remainingCredit => (creditLimit - currentBalance).clamp(0, double.infinity);

  CustomerModel copyWith({
    int? id,
    String? name,
    String? type,
    String? phone,
    double? creditLimit,
    double? currentBalance,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      phone: phone ?? this.phone,
      creditLimit: creditLimit ?? this.creditLimit,
      currentBalance: currentBalance ?? this.currentBalance,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type,
      'phone': phone,
      'credit_limit': creditLimit,
      'current_balance': currentBalance,
    };
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      type: map['type'] as String? ?? 'زبون دائم',
      phone: map['phone'] as String? ?? '',
      creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        phone,
        creditLimit,
        currentBalance,
      ];
}
