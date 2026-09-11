import 'package:equatable/equatable.dart';

class PumpModel extends Equatable {
  final int? id;
  final String name;
  final int tankId;
  final int nozzleNumber; // 1 to 8

  const PumpModel({
    this.id,
    required this.name,
    required this.tankId,
    required this.nozzleNumber,
  });

  PumpModel copyWith({
    int? id,
    String? name,
    int? tankId,
    int? nozzleNumber,
  }) {
    return PumpModel(
      id: id ?? this.id,
      name: name ?? this.name,
      tankId: tankId ?? this.tankId,
      nozzleNumber: nozzleNumber ?? this.nozzleNumber,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'tank_id': tankId,
      'nozzle_number': nozzleNumber,
    };
  }

  factory PumpModel.fromMap(Map<String, dynamic> map) {
    return PumpModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      tankId: map['tank_id'] as int? ?? 1,
      nozzleNumber: map['nozzle_number'] as int? ?? 1,
    );
  }

  @override
  List<Object?> get props => [id, name, tankId, nozzleNumber];
}
