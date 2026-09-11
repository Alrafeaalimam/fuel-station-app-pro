import 'package:equatable/equatable.dart';

class ShiftModel extends Equatable {
  final int? id;
  final int closedByUserId;
  final String closeDatetime;
  final String status; // 'open' | 'closed'
  final String? notes;

  const ShiftModel({
    this.id,
    required this.closedByUserId,
    required this.closeDatetime,
    this.status = 'closed',
    this.notes,
  });

  ShiftModel copyWith({
    int? id,
    int? closedByUserId,
    String? closeDatetime,
    String? status,
    String? notes,
  }) {
    return ShiftModel(
      id: id ?? this.id,
      closedByUserId: closedByUserId ?? this.closedByUserId,
      closeDatetime: closeDatetime ?? this.closeDatetime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'closed_by_user_id': closedByUserId,
      'close_datetime': closeDatetime,
      'status': status,
      'notes': notes,
    };
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    return ShiftModel(
      id: (map['id'] as num?)?.toInt(),
      closedByUserId: (map['closed_by_user_id'] as num?)?.toInt() ?? 1,
      closeDatetime: map['close_datetime']?.toString() ?? DateTime.now().toIso8601String(),
      status: map['status']?.toString() ?? 'closed',
      notes: map['notes']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, closedByUserId, closeDatetime, status, notes];
}
