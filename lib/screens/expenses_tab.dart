import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../services/database_helper.dart';

class ExpensesListTab extends StatefulWidget {
  const ExpensesListTab({super.key});

  @override
  State<ExpensesListTab> createState() => _ExpensesListTabState();
}

class _ExpensesListTabState extends State<ExpensesListTab> {
  final List<ExpenseItem> _expenses = [];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  String _filterType = 'Today'; 

  @override
  void initState() {
    super.initState();
    _refreshExpenses();
  }

  Future<void> _refreshExpenses() async {
    final data = await DatabaseHelper.instance.getExpenses();
    if (mounted) setState(() { _expenses.clear(); _expenses.addAll(data); });
  }

  double _calculateFilteredTotal() {
    final now = DateTime.now();
    double total = 0.0;
    for (var expense in _expenses) {
      bool include = false;
      final date = expense.date;
      if (_filterType == 'Today') { if (date.year == now.year && date.month == now.month && date.day == now.day) include = true; } 
      else if (_filterType == 'Week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        final nDate = DateTime(date.year, date.month, date.day);
        final nStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final nEnd = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);
        if ((nDate.isAfter(nStart) || nDate.isAtSameMomentAs(nStart)) && (nDate.isBefore(nEnd) || nDate.isAtSameMomentAs(nEnd))) include = true;
      } else if (_filterType == 'Month') { if (date.month == now.month && date.year == now.year) include = true; } 
      else if (_filterType == 'Year') { if (date.year == now.year) include = true; }
      if (include) total += expense.amount;
    }
    return total;
  }

  void _addExpense() {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('New Expense'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _titleController, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Description')),
        TextField(controller: _costController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '₱ ')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saveExpense, style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text('Add')),
      ],
    ));
  }

  void _saveExpense() async {
    if (_titleController.text.isNotEmpty && _costController.text.isNotEmpty) {
      final amount = double.tryParse(_costController.text);
      if (amount != null) {
        final expense = ExpenseItem(title: _titleController.text, amount: amount, date: DateTime.now());
        await DatabaseHelper.instance.insertExpense(expense);
        _titleController.clear(); _costController.clear();
        _refreshExpenses(); if (mounted) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text('Expenses', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true, backgroundColor: Colors.white, elevation: 0),
      body: Column(children: [
        Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.redAccent.shade700, Colors.redAccent.shade400], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))]), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(Icons.calendar_today, color: Colors.white, size: 16)), const SizedBox(width: 8), Text("Total Expenses ($_filterType)", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500))]),
          const SizedBox(height: 10), Text("₱${_calculateFilteredTotal().toStringAsFixed(2)}", style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
        ])),
        Container(height: 40, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: ListView(scrollDirection: Axis.horizontal, children: ['Today', 'Week', 'Month', 'Year'].map((type) => GestureDetector(onTap: () => setState(() => _filterType = type), child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), margin: const EdgeInsets.only(right: 10), decoration: BoxDecoration(color: _filterType == type ? Colors.redAccent : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _filterType == type ? Colors.redAccent : Colors.grey.shade300)), child: Text(type, style: TextStyle(color: _filterType == type ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold))))).toList())),
        Expanded(child: _expenses.isEmpty ? const Center(child: Text("No expenses yet", style: TextStyle(color: Colors.grey))) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), itemCount: _expenses.length, itemBuilder: (context, index) {
          final item = _expenses[index];
          return Dismissible(
            key: ValueKey(item.id), direction: DismissDirection.endToStart,
            onDismissed: (direction) async {
              if (item.id != null) await DatabaseHelper.instance.deleteExpense(item.id!);
              setState(() => _expenses.removeAt(index));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.title} deleted'), backgroundColor: Colors.red, duration: const Duration(seconds: 2)));
            },
            background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(16)), child: Icon(Icons.delete, color: Colors.red.shade700, size: 30)),
            child: Card(elevation: 2, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: ListTile(leading: CircleAvatar(backgroundColor: Colors.red.shade50, child: const Icon(Icons.shopping_bag, color: Colors.redAccent)), title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(DateFormat.yMMMd().format(item.date)), trailing: Text("-₱${item.amount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)))),
          );
        })),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: _addExpense, backgroundColor: Colors.redAccent, child: const Icon(Icons.add, color: Colors.white)),
    );
  }
}