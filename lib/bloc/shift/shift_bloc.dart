import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/shift_repository.dart';
import '../../data/repositories/tank_repository.dart';
import '../../data/repositories/fuel_price_repository.dart';
import '../../data/repositories/customer_repository.dart';
import 'shift_event.dart';
import 'shift_state.dart';

class ShiftBloc extends Bloc<ShiftEvent, ShiftState> {
  final ShiftRepository shiftRepository;
  final TankRepository tankRepository;
  final FuelPriceRepository fuelPriceRepository;
  final CustomerRepository customerRepository;

  ShiftBloc({
    required this.shiftRepository,
    required this.tankRepository,
    required this.fuelPriceRepository,
    required this.customerRepository,
  }) : super(const ShiftState()) {
    on<LoadShiftClosingData>(_onLoadShiftClosingData);
    on<SubmitCloseShiftRequested>(_onSubmitCloseShiftRequested);
    on<LoadShiftHistory>(_onLoadShiftHistory);
    on<LoadShiftDetailsRequested>(_onLoadShiftDetailsRequested);
    on<ResetShiftCloseStatus>(_onResetShiftCloseStatus);
  }

  void _onResetShiftCloseStatus(
    ResetShiftCloseStatus event,
    Emitter<ShiftState> emit,
  ) {
    emit(state.copyWith(
      clearCloseSuccess: true,
      clearSubmitError: true,
    ));
  }

  Future<void> _onLoadShiftClosingData(
    LoadShiftClosingData event,
    Emitter<ShiftState> emit,
  ) async {
    emit(state.copyWith(
      closingStatus: ShiftClosingStatus.loading,
      clearClosingError: true,
      clearCloseSuccess: true,
      clearSubmitError: true,
    ));
    try {
      final tanks = await tankRepository
          .getTanks()
          .timeout(const Duration(seconds: 10));
      final pumps = await tankRepository
          .getPumps()
          .timeout(const Duration(seconds: 10));
      final prices = await fuelPriceRepository
          .getActivePrices()
          .timeout(const Duration(seconds: 10));
      final lastShift = await shiftRepository
          .getLastClosedShift()
          .timeout(const Duration(seconds: 10));
      final customers = await customerRepository
          .getCustomers()
          .timeout(const Duration(seconds: 10));

      final Map<int, dynamic> tankMap = {for (var t in tanks) t.id!: t};

      final List<PumpShiftInitData> pumpDataList = [];
      for (final pump in pumps) {
        final tank = tankMap[pump.tankId];
        final prevMeter = await shiftRepository
            .getLastMeterForPump(pump.id!)
            .timeout(const Duration(seconds: 5));
        final activePrice = prices[tank?.fuelType]?.pricePerLiter ?? 0.0;

        pumpDataList.add(PumpShiftInitData(
          pump: pump,
          tank: tank,
          previousMeter: prevMeter,
          activePrice: activePrice,
        ));
      }

      final List<TankShiftInitData> tankDataList = [];
      for (final tank in tanks) {
        final prevDip = await shiftRepository
            .getLastDipForTank(tank.id!)
            .timeout(const Duration(seconds: 5));
        final delivered = await shiftRepository
            .getDeliveredSince(tank.id!, lastShift?.closeDatetime)
            .timeout(const Duration(seconds: 5));

        tankDataList.add(TankShiftInitData(
          tank: tank,
          previousDip: prevDip,
          deliveredDuringShift: delivered,
        ));
      }

      emit(state.copyWith(
        closingStatus: ShiftClosingStatus.loaded,
        pumpDataList: pumpDataList,
        tankDataList: tankDataList,
        customers: customers,
        lastShift: lastShift,
        clearClosingError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        closingStatus: ShiftClosingStatus.error,
        closingErrorMessage: 'خطأ أثناء تجهيز بيانات قفل الوردية: $e',
      ));
    }
  }

  Future<void> _onSubmitCloseShiftRequested(
    SubmitCloseShiftRequested event,
    Emitter<ShiftState> emit,
  ) async {
    emit(state.copyWith(
      isSubmitting: true,
      clearSubmitError: true,
      clearCloseSuccess: true,
    ));
    try {
      final shiftId = await shiftRepository
          .closeShift(
            shift: event.shift,
            readings: event.readings,
            summary: event.summary,
            tankNewDips: event.tankNewDips,
            creditTransactions: event.creditTransactions,
          )
          .timeout(const Duration(seconds: 15));

      emit(state.copyWith(
        isSubmitting: false,
        closeSuccess: ShiftCloseSuccess(
          shiftId: shiftId,
          message:
              'تم إغلاق الوردية رقم #$shiftId وحفظ القراءات وترحيل الخزنة بنجاح',
        ),
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        submitErrorMessage: 'خطأ أثناء إغلاق الوردية: $e',
      ));
    }
  }

  Future<void> _onLoadShiftHistory(
    LoadShiftHistory event,
    Emitter<ShiftState> emit,
  ) async {
    emit(state.copyWith(
      historyStatus: ShiftHistoryStatus.loading,
      clearHistoryError: true,
      clearCloseSuccess: true,
      clearSubmitError: true,
    ));
    try {
      final shifts = await shiftRepository
          .getAllShifts()
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException(
            'انتهت مهلة استرجاع سجل الورديات من قاعدة البيانات (10 ثوانٍ). يرجى التحقق من اتصال أو ملف البيانات.');
      });

      if (shifts.isEmpty) {
        emit(state.copyWith(
          historyStatus: ShiftHistoryStatus.empty,
          shifts: const [],
          clearHistoryError: true,
        ));
      } else {
        emit(state.copyWith(
          historyStatus: ShiftHistoryStatus.loaded,
          shifts: shifts,
          clearHistoryError: true,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        historyStatus: ShiftHistoryStatus.error,
        historyErrorMessage: 'خطأ في تحميل سجل الورديات: $e',
      ));
    }
  }

  Future<void> _onLoadShiftDetailsRequested(
    LoadShiftDetailsRequested event,
    Emitter<ShiftState> emit,
  ) async {
    emit(state.copyWith(
      detailsStatus: ShiftDetailsStatus.loading,
      clearDetailsError: true,
    ));
    try {
      final details = await shiftRepository
          .getShiftDetails(event.shiftId)
          .timeout(const Duration(seconds: 10));
      if (details != null) {
        emit(state.copyWith(
          detailsStatus: ShiftDetailsStatus.loaded,
          selectedDetails: details,
          clearDetailsError: true,
        ));
      } else {
        emit(state.copyWith(
          detailsStatus: ShiftDetailsStatus.error,
          detailsErrorMessage:
              'لم يتم العثور على تفاصيل الوردية رقم #${event.shiftId}',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        detailsStatus: ShiftDetailsStatus.error,
        detailsErrorMessage: 'خطأ في تحميل تفاصيل الوردية: $e',
      ));
    }
  }
}
