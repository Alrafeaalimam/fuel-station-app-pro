import 'package:equatable/equatable.dart';
import '../../models/models.dart';

abstract class TankState extends Equatable {
  const TankState();

  @override
  List<Object?> get props => [];
}

class TankInitial extends TankState {}

class TankLoading extends TankState {}

class TankLoaded extends TankState {
  final List<TankModel> tanks;
  final List<PumpModel> pumps;

  const TankLoaded({required this.tanks, required this.pumps});

  @override
  List<Object?> get props => [tanks, pumps];
}

class TankError extends TankState {
  final String message;

  const TankError(this.message);

  @override
  List<Object?> get props => [message];
}

class TankActionSuccess extends TankState {
  final String message;

  const TankActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}
