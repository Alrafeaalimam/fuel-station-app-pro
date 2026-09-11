import 'package:equatable/equatable.dart';

class SupplierModel extends Equatable {
  final int? id;
  final String name;
  final String phone;

  const SupplierModel({
    this.id,
    required this.name,
    required this.phone,
  });

  SupplierModel copyWith({
    int? id,
    String? name,
    String? phone,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
    };
  }

  factory SupplierModel.fromMap(Map<String, dynamic> map) {
    return SupplierModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id, name, phone];
}
