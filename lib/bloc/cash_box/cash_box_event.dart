import 'package:equatable/equatable.dart';
import '../../models/user_model.dart';

abstract class CashBoxEvent extends Equatable {
  const CashBoxEvent();

  @override
  List<Object?> get props => [];
}

class LoadCashBox extends CashBoxEvent {}

class UpdateCashBoxManualRequested extends CashBoxEvent {
  final double cashInDelta;
  final double cashOutDelta;
  final String? notes;
  final UserModel? user;

  const UpdateCashBoxManualRequested({
    this.cashInDelta = 0.0,
    this.cashOutDelta = 0.0,
    this.notes,
    this.user,
  });

  @override
  List<Object?> get props => [cashInDelta, cashOutDelta, notes, user];
}
