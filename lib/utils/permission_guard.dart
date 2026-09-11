import '../models/user_model.dart';

enum AppPermission {
  /// تعديل التسعيرة الرسمية للوقود (مدير فقط)
  editFuelPrices,

  /// تعديل أو تحديد السقف الائتماني للعملاء (مدير فقط)
  editCustomerCreditLimit,

  /// إضافة أو تعديل أو حذف الموردين (مدير فقط)
  manageSuppliers,

  /// إدارة المستخدمين والحسابات (مدير فقط)
  manageUsers,

  /// إدارة النسخ الاحتياطي والاستعادة (مدير فقط)
  manageBackup,

  /// تحديد وتعديل سعة وبيانات الخزانات (مدير فقط)
  manageTanks,

  /// تعديل رصيد الخزنة يدوياً (مدير فقط)
  adjustCashBoxManually,

  /// الاطلاع على شاشة التقارير الاستراتيجية والأرباح الشاملة (مدير فقط)
  viewStrategicReports,

  /// العمليات التشغيلية اليومية (متاحة للمدير والمحاسب):
  closeShift,
  recordDelivery,
  recordCustomerPayment,
  recordExpense,
  viewOperationalReports,
}

class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException([
    this.message = 'غير مصرح لك بإجراء هذه العملية. هذه الصلاحية حصرية لمدير المحطة فقط.',
  ]);

  @override
  String toString() => message;
}

class PermissionGuard {
  /// فحص إذا كان للمستخدم صلاحية معينة
  static bool can(UserModel? user, AppPermission permission) {
    if (user == null) return false;
    // مدير المحطة يملك كافة الصلاحيات كاملة
    if (user.isManager) return true;

    // فحص صلاحيات المحاسب: الصلاحيات الحصرية للمدير مرفوضة تماماً
    switch (permission) {
      case AppPermission.editFuelPrices:
      case AppPermission.editCustomerCreditLimit:
      case AppPermission.manageSuppliers:
      case AppPermission.manageUsers:
      case AppPermission.manageBackup:
      case AppPermission.manageTanks:
      case AppPermission.adjustCashBoxManually:
      case AppPermission.viewStrategicReports:
        return false;

      case AppPermission.closeShift:
      case AppPermission.recordDelivery:
      case AppPermission.recordCustomerPayment:
      case AppPermission.recordExpense:
      case AppPermission.viewOperationalReports:
        return true;
    }
  }

  /// التحقق وإلقاء استثناء فوري إذا لم يكن المستخدم مخولاً
  static void check(UserModel? user, AppPermission permission) {
    if (!can(user, permission)) {
      throw const UnauthorizedException();
    }
  }
}
