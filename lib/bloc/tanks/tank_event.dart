import 'package:equatable/equatable.dart';
import '../../models/models.dart';

abstract class TankEvent extends Equatable {
  const TankEvent();

  @override
  List<Object?> get props => [];
}

class LoadTanksAndPumps extends TankEvent {}

class UpdateTankDipManually extends TankEvent {
  final int tankId;
  final double newDip;

  const UpdateTankDipManually({required this.tankId, required this.newDip});

  @override
  List<Object?> get props => [tankId, newDip];
}

class UpdateTankCapacityRequested extends TankEvent {
  final int tankId;
  final double capacityLiters;
  final UserModel? user;

  const UpdateTankCapacityRequested({
    required this.tankId,
    required this.capacityLiters,
    this.user,
  });

  @override
  List<Object?> get props => [tankId, capacityLiters, user];
}
