import 'package:equatable/equatable.dart';
import '../../models/models.dart';

abstract class ShiftEvent extends Equatable {
  const ShiftEvent();

  @override
  List<Object?> get props => [];
}

class LoadShiftClosingData extends ShiftEvent {}

class SubmitCloseShiftRequested extends ShiftEvent {
  final ShiftModel shift;
  final List<ShiftReadingModel> readings;
  final SalesSummaryModel summary;
  final Map<int, double> tankNewDips;
  final List<CreditTransactionModel> creditTransactions;

  const SubmitCloseShiftRequested({
    required this.shift,
    required this.readings,
    required this.summary,
    required this.tankNewDips,
    this.creditTransactions = const [],
  });

  @override
  List<Object?> get props => [
        shift,
        readings,
        summary,
        tankNewDips,
        creditTransactions,
      ];
}

class LoadShiftHistory extends ShiftEvent {}

class LoadShiftDetailsRequested extends ShiftEvent {
  final int shiftId;

  const LoadShiftDetailsRequested(this.shiftId);

  @override
  List<Object?> get props => [shiftId];
}

class ResetShiftCloseStatus extends ShiftEvent {}
