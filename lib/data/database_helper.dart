import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../utils/security_util.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static String? _currentDbPath;
  Database? _customDb;
  final String? _customDbPath;

  DatabaseHelper._init()
      : _customDb = null,
        _customDbPath = null;

  DatabaseHelper.withDatabase(Database db, {String? dbPath})
      : _customDb = db,
        _customDbPath = dbPath;

  DatabaseHelper.withFile(String dbPath)
      : _customDb = null,
        _customDbPath = dbPath;

  Future<Database> get database async {
    if (_customDb != null) {
      if (!_customDb!.isOpen && _customDbPath != null) {
        _customDb = await databaseFactory.openDatabase(_customDbPath);
      }
      return _customDb!;
    }
    if (_customDbPath != null) {
      _customDb = await databaseFactory.openDatabase(_customDbPath);
      return _customDb!;
    }
    if (_database != null) return _database!;
    _database = await _initDB('fuel_station_pro.db');
    return _database!;
  }

  Future<String> getDatabasePath() async {
    if (_customDbPath != null) return _customDbPath;
    if (_currentDbPath != null) return _currentDbPath!;
    if (kIsWeb) return 'fuel_station_pro.db';
    try {
      final directory = await getApplicationDocumentsDirectory();
      return join(directory.path, 'fuel_station_pro.db');
    } catch (_) {
      return 'fuel_station_pro.db';
    }
  }

  Future<Database> _initDB(String filePath) async {
    DatabaseFactory dbFactory;
    String dbPath;

    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
      dbFactory = databaseFactoryFfiWebNoWebWorker;
      dbPath = filePath;
    } else {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      dbFactory = databaseFactoryFfi;
      try {
        final directory = await getApplicationDocumentsDirectory();
        dbPath = join(directory.path, filePath);
      } catch (_) {
        dbPath = filePath;
      }
    }
    _currentDbPath = dbPath;

    return await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          try {
            await db.execute('PRAGMA foreign_keys = ON');
            await db.execute('PRAGMA journal_mode = WAL');
            await db.execute('PRAGMA busy_timeout = 5000');
          } catch (_) {}
        },
        onCreate: _createDB,
      ),
    );
  }

  Future<void> createDBForTesting(Database db) async {
    try {
      await db.execute('PRAGMA foreign_keys = ON');
      await db.execute('PRAGMA journal_mode = WAL');
      await db.execute('PRAGMA busy_timeout = 5000');
    } catch (_) {}
    await _createDB(db, 1);
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Users
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL
      )
    ''');

    // 2. Tanks
    await db.execute('''
      CREATE TABLE tanks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        fuel_type TEXT NOT NULL,
        capacity_liters REAL NOT NULL,
        current_dip_liters REAL NOT NULL
      )
    ''');

    // 3. Pumps
    await db.execute('''
      CREATE TABLE pumps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        tank_id INTEGER NOT NULL,
        nozzle_number INTEGER NOT NULL,
        FOREIGN KEY (tank_id) REFERENCES tanks (id)
      )
    ''');

    // 4. Fuel Prices
    await db.execute('''
      CREATE TABLE fuel_prices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fuel_type TEXT NOT NULL,
        price_per_liter REAL NOT NULL,
        effective_from TEXT NOT NULL,
        effective_to TEXT,
        set_by_user_id INTEGER,
        FOREIGN KEY (set_by_user_id) REFERENCES users (id)
      )
    ''');

    // 5. Shifts
    await db.execute('''
      CREATE TABLE shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        closed_by_user_id INTEGER NOT NULL,
        close_datetime TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'closed',
        notes TEXT,
        FOREIGN KEY (closed_by_user_id) REFERENCES users (id)
      )
    ''');

    // 6. Shift Readings
    await db.execute('''
      CREATE TABLE shift_readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shift_id INTEGER NOT NULL,
        pump_id INTEGER NOT NULL,
        previous_meter REAL NOT NULL,
        current_meter REAL NOT NULL,
        liters_sold REAL NOT NULL,
        previous_dip REAL NOT NULL,
        current_dip REAL NOT NULL,
        delivered_liters_during_shift REAL NOT NULL DEFAULT 0.0,
        surplus_deficit REAL NOT NULL,
        price_per_liter REAL NOT NULL,
        total_amount REAL NOT NULL,
        FOREIGN KEY (shift_id) REFERENCES shifts (id),
        FOREIGN KEY (pump_id) REFERENCES pumps (id)
      )
    ''');

    // 7. Sales Summary
    await db.execute('''
      CREATE TABLE sales_summary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shift_id INTEGER NOT NULL,
        cash_amount REAL NOT NULL,
        bank_transfer_amount REAL NOT NULL,
        credit_amount REAL NOT NULL,
        total_amount REAL NOT NULL,
        FOREIGN KEY (shift_id) REFERENCES shifts (id)
      )
    ''');

    // 8. Customers
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        phone TEXT NOT NULL,
        credit_limit REAL NOT NULL,
        current_balance REAL NOT NULL DEFAULT 0.0
      )
    ''');

    // 9. Credit Transactions
    await db.execute('''
      CREATE TABLE credit_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        shift_id INTEGER,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        transaction_date TEXT NOT NULL,
        notes TEXT,
        settled INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (customer_id) REFERENCES customers (id),
        FOREIGN KEY (shift_id) REFERENCES shifts (id)
      )
    ''');

    // 10. Suppliers
    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL
      )
    ''');

    // 11. Deliveries
    await db.execute('''
      CREATE TABLE deliveries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        tank_id INTEGER NOT NULL,
        liters REAL NOT NULL,
        cost_per_liter REAL NOT NULL,
        total_cost REAL NOT NULL,
        delivered_at TEXT NOT NULL,
        recorded_by_user_id INTEGER NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id),
        FOREIGN KEY (tank_id) REFERENCES tanks (id),
        FOREIGN KEY (recorded_by_user_id) REFERENCES users (id)
      )
    ''');

    // 12. Cash Box
    await db.execute('''
      CREATE TABLE cash_box (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        opening_balance REAL NOT NULL,
        cash_in REAL NOT NULL,
        cash_out REAL NOT NULL,
        closing_balance REAL NOT NULL,
        notes TEXT
      )
    ''');

    // 13. Expenses
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        recorded_by_user_id INTEGER NOT NULL,
        FOREIGN KEY (recorded_by_user_id) REFERENCES users (id)
      )
    ''');

    // 14. Settings
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now().toIso8601String();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // 1. Station settings
    await db.insert('settings', {
      'key': 'station_name',
      'value': 'محطة الوقود النموذجية',
    });

    // 2. Seed default users (manager / accountant) with SHA-256 password hashes
    await db.insert('users', {
      'name': 'المدير العام',
      'username': 'admin',
      'password_hash': SecurityUtil.hashPassword('admin123'),
      'role': 'manager',
    });

    await db.insert('users', {
      'name': 'المحاسب المالي',
      'username': 'accountant',
      'password_hash': SecurityUtil.hashPassword('acc123'),
      'role': 'accountant',
    });

    // 3. Seed 2 tanks: بنزين and جازولين (clean initial baseline: dip = 0, capacity = 0)
    final benzinTankId = await db.insert('tanks', {
      'name': 'خزان بنزين رقم (1)',
      'fuel_type': 'بنزين',
      'capacity_liters': 0.0,
      'current_dip_liters': 0.0,
    });

    final dieselTankId = await db.insert('tanks', {
      'name': 'خزان جازولين رقم (1)',
      'fuel_type': 'جازولين',
      'capacity_liters': 0.0,
      'current_dip_liters': 0.0,
    });

    // 4. Seed 8 pumps (4 for Benzin tank, 4 for Gasolin tank)
    for (int i = 1; i <= 4; i++) {
      await db.insert('pumps', {
        'name': 'فوهة بنزين رقم $i',
        'tank_id': benzinTankId,
        'nozzle_number': i,
      });
    }

    for (int i = 1; i <= 4; i++) {
      await db.insert('pumps', {
        'name': 'فوهة جازولين رقم $i',
        'tank_id': dieselTankId,
        'nozzle_number': i + 4,
      });
    }

    // 5. Seed initial fuel prices (0.0 until set by manager)
    await db.insert('fuel_prices', {
      'fuel_type': 'بنزين',
      'price_per_liter': 0.0,
      'effective_from': now,
      'effective_to': null,
      'set_by_user_id': 1,
    });

    await db.insert('fuel_prices', {
      'fuel_type': 'جازولين',
      'price_per_liter': 0.0,
      'effective_from': now,
      'effective_to': null,
      'set_by_user_id': 1,
    });

    // 6. Seed initial cash box for today (0.0 balance)
    await db.insert('cash_box', {
      'date': today,
      'opening_balance': 0.0,
      'cash_in': 0.0,
      'cash_out': 0.0,
      'closing_balance': 0.0,
      'notes': 'رصيد افتتاحي لبداية التشغيل',
    });
  }

  // Generic close method
  Future<void> close() async {
    if (_customDb != null) {
      if (_customDb!.isOpen) {
        await _customDb!.close();
      }
      _customDb = null;
    }
    if (_database != null) {
      if (_database!.isOpen) {
        await _database!.close();
      }
      _database = null;
    }
  }
}
