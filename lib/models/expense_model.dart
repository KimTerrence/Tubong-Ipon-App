// lib/models/expense_model.dart

class ExpenseItem {
  final int? id; // Added ID for database
  final String title;
  final double amount;
  final DateTime date;

  ExpenseItem({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
  });

  // Convert to Map for Database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  // Create Object from Database Map
  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    return ExpenseItem(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
    );
  }
}