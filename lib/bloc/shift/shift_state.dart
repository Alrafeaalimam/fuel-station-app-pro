import 'package:equatable/equatable.dart';
import '../../models/models.dart';
import '../../data/repositories/shift_repository.dart';

class PumpShiftInitData extends Equatable {
  final PumpModel pump;
  final TankModel tank;
  final double previousMeter;
  final double activePrice;

  const PumpShiftInitData({
    required this.pump,
    required this.tank,
    required this.previousMeter,
    required this.activePrice,
  });

  @override
  List<Object?> get props => [pump, tank, previousMeter, activePrice];
}

class TankShiftInitData extends Equatable {
  final TankModel tank;
  final double previousDip;
  final double deliveredDuringShift;

  const TankShiftInitData({
    required this.tank,
    required this.previousDip,
    required this.deliveredDuringShift,
  });

  @override
  List<Object?> get props => [tank, previousDip, deliveredDuringShift];
}

class ShiftCloseSuccess extends Equatable {
  final int shiftId;
  final String message;

  const ShiftCloseSuccess({required this.shiftId, required this.message});

  @override
  List<Object?> get props => [shiftId, message];
}

enum ShiftClosingStatus { initial, loading, loaded, error }

enum ShiftHistoryStatus { initial, loading, loaded, empty, error }

enum ShiftDetailsStatus { initial, loading, loaded, error }

class ShiftState extends Equatable {
  // 1. Tab: Closing Current Shift
  final ShiftClosingStatus closingStatus;
  final List<PumpShiftInitData> pumpDataList;
  final List<TankShiftInitData> tankDataList;
  final List<CustomerModel> customers;
  final ShiftModel? lastShift;
  final String? closingErrorMessage;

  // 2. Tab: Shift History
  final ShiftHistoryStatus historyStatus;
  final List<ShiftModel> shifts;
  final String? historyErrorMessage;

  // 3. Modal: Shift Details
  final ShiftDetailsStatus detailsStatus;
  final ShiftDetails? selectedDetails;
  final String? detailsErrorMessage;

  // 4. Submission
  final bool isSubmitting;
  final ShiftCloseSuccess? closeSuccess;
  final String? submitErrorMessage;

  const ShiftState({
    this.closingStatus = ShiftClosingStatus.initial,
    this.pumpDataList = const [],
    this.tankDataList = const [],
    this.customers = const [],
    this.lastShift,
    this.closingErrorMessage,
    this.historyStatus = ShiftHistoryStatus.initial,
    this.shifts = const [],
    this.historyErrorMessage,
    this.detailsStatus = ShiftDetailsStatus.initial,
    this.selectedDetails,
    this.detailsErrorMessage,
    this.isSubmitting = false,
    this.closeSuccess,
    this.submitErrorMessage,
  });

  // Explicit history status getters
  bool get isHistoryLoading => historyStatus == ShiftHistoryStatus.loading;
  bool get isHistoryLoaded => historyStatus == ShiftHistoryStatus.loaded;
  bool get isHistoryEmpty => historyStatus == ShiftHistoryStatus.empty;
  bool get isHistoryError => historyStatus == ShiftHistoryStatus.error;

  // Explicit closing status getters
  bool get isClosingLoading => closingStatus == ShiftClosingStatus.loading;
  bool get isClosingLoaded => closingStatus == ShiftClosingStatus.loaded;
  bool get isClosingError => closingStatus == ShiftClosingStatus.error;

  ShiftState copyWith({
    ShiftClosingStatus? closingStatus,
    List<PumpShiftInitData>? pumpDataList,
    List<TankShiftInitData>? tankDataList,
    List<CustomerModel>? customers,
    ShiftModel? lastShift,
    bool clearLastShift = false,
    String? closingErrorMessage,
    bool clearClosingError = false,
    ShiftHistoryStatus? historyStatus,
    List<ShiftModel>? shifts,
    String? historyErrorMessage,
    bool clearHistoryError = false,
    ShiftDetailsStatus? detailsStatus,
    ShiftDetails? selectedDetails,
    bool clearSelectedDetails = false,
    String? detailsErrorMessage,
    bool clearDetailsError = false,
    bool? isSubmitting,
    ShiftCloseSuccess? closeSuccess,
    bool clearCloseSuccess = false,
    String? submitErrorMessage,
    bool clearSubmitError = false,
  }) {
    return ShiftState(
      closingStatus: closingStatus ?? this.closingStatus,
      pumpDataList: pumpDataList ?? this.pumpDataList,
      tankDataList: tankDataList ?? this.tankDataList,
      customers: customers ?? this.customers,
      lastShift: clearLastShift ? null : (lastShift ?? this.lastShift),
      closingErrorMessage:
          clearClosingError ? null : (closingErrorMessage ?? this.closingErrorMessage),
      historyStatus: historyStatus ?? this.historyStatus,
      shifts: shifts ?? this.shifts,
      historyErrorMessage:
          clearHistoryError ? null : (historyErrorMessage ?? this.historyErrorMessage),
      detailsStatus: detailsStatus ?? this.detailsStatus,
      selectedDetails:
          clearSelectedDetails ? null : (selectedDetails ?? this.selectedDetails),
      detailsErrorMessage:
          clearDetailsError ? null : (detailsErrorMessage ?? this.detailsErrorMessage),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      closeSuccess: clearCloseSuccess ? null : (closeSuccess ?? this.closeSuccess),
      submitErrorMessage:
          clearSubmitError ? null : (submitErrorMessage ?? this.submitErrorMessage),
    );
  }

  @override
  List<Object?> get props => [
        closingStatus,
        pumpDataList,
        tankDataList,
        customers,
        lastShift,
        closingErrorMessage,
        historyStatus,
        shifts,
        historyErrorMessage,
        detailsStatus,
        selectedDetails,
        detailsErrorMessage,
        isSubmitting,
        closeSuccess,
        submitErrorMessage,
      ];
}
