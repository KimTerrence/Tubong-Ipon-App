import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('finance_tracker_final.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('CREATE TABLE savings (date TEXT PRIMARY KEY, amount REAL)');
    await db.execute('CREATE TABLE expenses (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, date TEXT)');
    await db.execute('CREATE TABLE income (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, date TEXT)');
    
    // LOGS TABLE: Stores deleted items
    await db.execute('''
      CREATE TABLE activity_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        amount REAL,
        date TEXT,
        type TEXT
      )
    ''');
  }

  // --- LOGGING ---
  Future<List<Map<String, dynamic>>> getLogs() async {
    final db = await instance.database;
    return await db.query('activity_logs', orderBy: 'date DESC');
  }

  // --- INCOME ---
  Future<void> insertIncome(String title, double amount) async {
    final db = await instance.database;
    await db.insert('income', {'title': title, 'amount': amount, 'date': DateTime.now().toIso8601String()});
  }

  Future<List<Map<String, dynamic>>> getIncomes() async {
    final db = await instance.database;
    return await db.query('income', orderBy: 'date DESC');
  }

  Future<void> deleteIncome(int id) async {
    final db = await instance.database;
    await db.delete('income', where: 'id = ?', whereArgs: [id]);
  }

  // --- EXPENSES (With Logging Logic) ---
  Future<void> insertExpense(ExpenseItem expense) async {
    final db = await instance.database;
    await db.insert('expenses', expense.toMap());
  }

  Future<List<ExpenseItem>> getExpenses() async {
    final db = await instance.database;
    final result = await db.query('expenses', orderBy: 'date DESC');
    return result.map((json) => ExpenseItem.fromMap(json)).toList();
  }

  // THE FIX: Move to logs before deleting
  Future<void> deleteExpense(int id) async {
    final db = await instance.database;
    
    // 1. Get item details
    final result = await db.query('expenses', where: 'id = ?', whereArgs: [id]);
    
    if (result.isNotEmpty) {
      final item = result.first;
      // 2. Add to logs
      await db.insert('activity_logs', {
        'title': 'Deleted: ${item['title']}',
        'amount': item['amount'],
        'date': DateTime.now().toIso8601String(),
        'type': 'deletion'
      });
    }

    // 3. Delete from active expenses
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // --- SAVINGS ---
  Future<void> insertSaving(DateTime date, double amount) async {
    final db = await instance.database;
    final dateString = date.toIso8601String().split('T')[0];
    await db.insert('savings', {'date': dateString, 'amount': amount}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSaving(DateTime date) async {
    final db = await instance.database;
    final dateString = date.toIso8601String().split('T')[0];
    await db.delete('savings', where: 'date = ?', whereArgs: [dateString]);
  }

  Future<Map<DateTime, double>> getSavings() async {
    final db = await instance.database;
    final result = await db.query('savings');
    final Map<DateTime, double> savingsMap = {};
    for (var row in result) {
      final date = DateTime.parse(row['date'] as String);
      final utcDate = DateTime.utc(date.year, date.month, date.day);
      savingsMap[utcDate] = row['amount'] as double;
    }
    return savingsMap;
  }

  // --- DASHBOARD TOTALS ---
  Future<Map<String, double>> getTotals() async {
    final db = await instance.database;
    final inc = await db.rawQuery('SELECT SUM(amount) as total FROM income');
    final exp = await db.rawQuery('SELECT SUM(amount) as total FROM expenses');
    final sav = await db.rawQuery('SELECT SUM(amount) as total FROM savings');
    
    final tInc = (inc.first['total'] as double?) ?? 0.0;
    final tExp = (exp.first['total'] as double?) ?? 0.0;
    final tSav = (sav.first['total'] as double?) ?? 0.0;
    
    return {'income': tInc, 'expenses': tExp, 'savings': tSav, 'balance': tInc - tExp};
  }

  // --- SETTINGS: CLEAR ALL DATA ---
  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.delete('savings');
    await db.delete('expenses');
    await db.delete('income');
    await db.delete('activity_logs');
  }
}