// lib/services/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('finance_tracker_v2.db'); // Changed name to force new DB creation
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // 1. Daily Savings (Calendar)
    await db.execute('''
      CREATE TABLE savings (
        date TEXT PRIMARY KEY, 
        amount REAL
      )
    ''');

    // 2. Expenses
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        amount REAL,
        date TEXT
      )
    ''');

    // 3. NEW: Income Table
    await db.execute('''
      CREATE TABLE income (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        amount REAL,
        date TEXT
      )
    ''');
  }

  // --- INCOME OPERATIONS (NEW) ---
  Future<void> insertIncome(String title, double amount) async {
    final db = await instance.database;
    await db.insert('income', {
      'title': title,
      'amount': amount,
      'date': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getIncomes() async {
    final db = await instance.database;
    return await db.query('income', orderBy: 'date DESC');
  }

  // --- SAVINGS OPERATIONS ---
  Future<void> insertSaving(DateTime date, double amount) async {
    final db = await instance.database;
    final dateString = date.toIso8601String().split('T')[0];
    await db.insert(
      'savings',
      {'date': dateString, 'amount': amount},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

  // --- EXPENSE OPERATIONS ---
  Future<void> insertExpense(ExpenseItem expense) async {
    final db = await instance.database;
    await db.insert('expenses', expense.toMap());
  }

  Future<List<ExpenseItem>> getExpenses() async {
    final db = await instance.database;
    final result = await db.query('expenses', orderBy: 'date DESC');
    return result.map((json) => ExpenseItem.fromMap(json)).toList();
  }

  Future<void> deleteExpense(int id) async {
    final db = await instance.database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }
  
  // --- DASHBOARD TOTALS (UPDATED) ---
  Future<Map<String, double>> getTotals() async {
    final db = await instance.database;
    
    // Sum Income
    final incomeRes = await db.rawQuery('SELECT SUM(amount) as total FROM income');
    final double totalIncome = (incomeRes.first['total'] as double?) ?? 0.0;

    // Sum Expenses
    final expensesRes = await db.rawQuery('SELECT SUM(amount) as total FROM expenses');
    final double totalExpenses = (expensesRes.first['total'] as double?) ?? 0.0;
    
    // Sum Savings (Calendar) - kept separate
    final savingsRes = await db.rawQuery('SELECT SUM(amount) as total FROM savings');
    final double totalSavings = (savingsRes.first['total'] as double?) ?? 0.0;
    
    return {
      'income': totalIncome,     // Total Money In
      'expenses': totalExpenses, // Total Money Out
      'savings': totalSavings,   // Money set aside (Piggy Bank)
      'balance': totalIncome - totalExpenses, // Net Balance
    };
  }
}