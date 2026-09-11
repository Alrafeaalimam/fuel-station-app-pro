import 'package:equatable/equatable.dart';

abstract class ReportsEvent extends Equatable {
  const ReportsEvent();

  @override
  List<Object?> get props => [];
}

class LoadFinancialSummaryReport extends ReportsEvent {
  final String? fromDate;
  final String? toDate;

  const LoadFinancialSummaryReport({this.fromDate, this.toDate});

  @override
  List<Object?> get props => [fromDate, toDate];
}
