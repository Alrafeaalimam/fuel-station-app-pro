import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/customer_repository.dart';
import 'customer_event.dart';
import 'customer_state.dart';
import '../../utils/permission_guard.dart';

class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  final CustomerRepository customerRepository;

  CustomerBloc({required this.customerRepository}) : super(CustomerInitial()) {
    on<LoadCustomers>(_onLoadCustomers);
    on<AddCustomerRequested>(_onAddCustomerRequested);
    on<UpdateCustomerRequested>(_onUpdateCustomerRequested);
    on<RecordCustomerPaymentRequested>(_onRecordCustomerPaymentRequested);
    on<LoadCustomerStatementRequested>(_onLoadCustomerStatementRequested);
  }

  Future<void> _onLoadCustomers(
    LoadCustomers event,
    Emitter<CustomerState> emit,
  ) async {
    emit(CustomerLoading());
    try {
      final customers = await customerRepository.getCustomers();
      emit(CustomerLoaded(customers));
    } catch (e) {
      emit(CustomerError('خطأ في تحميل بيانات العملاء: $e'));
    }
  }

  Future<void> _onAddCustomerRequested(
    AddCustomerRequested event,
    Emitter<CustomerState> emit,
  ) async {
    try {
      await customerRepository.addCustomer(event.customer, user: event.user);
      emit(const CustomerActionSuccess('تمت إضافة العميل بنجاح'));
      add(LoadCustomers());
    } catch (e) {
      final msg = e is UnauthorizedException ? e.message : 'خطأ أثناء إضافة العميل: $e';
      emit(CustomerError(msg));
    }
  }

  Future<void> _onUpdateCustomerRequested(
    UpdateCustomerRequested event,
    Emitter<CustomerState> emit,
  ) async {
    try {
      await customerRepository.updateCustomer(event.customer, user: event.user);
      emit(const CustomerActionSuccess('تم تعديل بيانات العميل بنجاح'));
      add(LoadCustomers());
    } catch (e) {
      final msg = e is UnauthorizedException ? e.message : 'خطأ أثناء تعديل بيانات العميل: $e';
      emit(CustomerError(msg));
    }
  }

  Future<void> _onRecordCustomerPaymentRequested(
    RecordCustomerPaymentRequested event,
    Emitter<CustomerState> emit,
  ) async {
    try {
      await customerRepository.recordPayment(
        customerId: event.customerId,
        amount: event.amount,
        notes: event.notes,
      );
      emit(const CustomerActionSuccess('تم تسجيل سند القبض وسداد الدفعة بنجاح'));
      add(LoadCustomers());
    } catch (e) {
      emit(CustomerError('خطأ أثناء تسجيل الدفعة: $e'));
    }
  }

  Future<void> _onLoadCustomerStatementRequested(
    LoadCustomerStatementRequested event,
    Emitter<CustomerState> emit,
  ) async {
    emit(CustomerLoading());
    try {
      final customer = await customerRepository.getCustomerById(event.customerId);
      if (customer == null) {
        emit(const CustomerError('العميل غير موجود'));
        return;
      }
      final txns = await customerRepository.getCustomerTransactions(
        event.customerId,
        fromDate: event.fromDate,
        toDate: event.toDate,
      );

      double charges = 0.0;
      double payments = 0.0;
      for (final t in txns) {
        if (t.isCharge) {
          charges += t.amount;
        } else if (t.isPayment) {
          payments += t.amount;
        }
      }

      emit(CustomerStatementLoaded(
        customer: customer,
        transactions: txns,
        totalCharges: charges,
        totalPayments: payments,
      ));
    } catch (e) {
      emit(CustomerError('خطأ في تحميل كشف الحساب: $e'));
    }
  }
}
