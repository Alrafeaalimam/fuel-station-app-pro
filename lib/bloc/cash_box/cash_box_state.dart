import 'package:equatable/equatable.dart';
import '../../models/models.dart';

abstract class CashBoxState extends Equatable {
  const CashBoxState();

  @override
  List<Object?> get props => [];
}

class CashBoxInitial extends CashBoxState {}

class CashBoxLoading extends CashBoxState {}

class CashBoxLoaded extends CashBoxState {
  final CashBoxModel todayBox;
  final List<CashBoxModel> history;

  const CashBoxLoaded({required this.todayBox, required this.history});

  @override
  List<Object?> get props => [todayBox, history];
}

class CashBoxActionSuccess extends CashBoxState {
  final String message;

  const CashBoxActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class CashBoxError extends CashBoxState {
  final String message;

  const CashBoxError(this.message);

  @override
  List<Object?> get props => [message];
}
