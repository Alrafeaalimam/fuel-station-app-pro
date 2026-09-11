import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/fuel_price_repository.dart';
import 'fuel_price_event.dart';
import 'fuel_price_state.dart';

class FuelPriceBloc extends Bloc<FuelPriceEvent, FuelPriceState> {
  final FuelPriceRepository fuelPriceRepository;

  FuelPriceBloc({required this.fuelPriceRepository}) : super(FuelPriceInitial()) {
    on<LoadFuelPrices>(_onLoadFuelPrices);
    on<UpdateFuelPriceRequested>(_onUpdateFuelPriceRequested);
  }

  Future<void> _onLoadFuelPrices(
    LoadFuelPrices event,
    Emitter<FuelPriceState> emit,
  ) async {
    emit(FuelPriceLoading());
    try {
      final active = await fuelPriceRepository.getActivePrices();
      final history = await fuelPriceRepository.getAllPrices();
      emit(FuelPriceLoaded(activePrices: active, priceHistory: history));
    } catch (e) {
      emit(FuelPriceError('خطأ في تحميل أسعار الوقود: $e'));
    }
  }

  Future<void> _onUpdateFuelPriceRequested(
    UpdateFuelPriceRequested event,
    Emitter<FuelPriceState> emit,
  ) async {
    try {
      await fuelPriceRepository.setNewPrice(
        fuelType: event.fuelType,
        newPrice: event.newPrice,
        userId: event.userId,
      );
      emit(FuelPriceUpdateSuccess('تم تحديث سعر ${event.fuelType} بنجاح'));
      add(LoadFuelPrices());
    } catch (e) {
      emit(FuelPriceError('خطأ في تحديث السعر: $e'));
    }
  }
}
