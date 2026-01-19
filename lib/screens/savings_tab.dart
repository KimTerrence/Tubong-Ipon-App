import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../models/expense_model.dart';

class SavingsCalendarTab extends StatefulWidget {
  const SavingsCalendarTab({super.key});

  @override
  State<SavingsCalendarTab> createState() => _SavingsCalendarTabState();
}

class _SavingsCalendarTabState extends State<SavingsCalendarTab> {
  Map<DateTime, double> _savings = {};
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshSavings();
  }

  Future<void> _refreshSavings() async {
    final data = await DatabaseHelper.instance.getSavings();
    if (mounted) setState(() => _savings = data);
  }

  DateTime _normalizeDate(DateTime date) => DateTime.utc(date.year, date.month, date.day);

  double _calculateTotal() {
    double total = 0.0;
    _savings.forEach((_, amount) => total += amount);
    return total;
  }

  void _showSavingsModal(BuildContext context, DateTime date) {
    final normalizedDate = _normalizeDate(date);
    _amountController.text = _savings.containsKey(normalizedDate) ? _savings[normalizedDate].toString() : '';

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 24, right: 24, top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Column(children: [
              Text('Savings for', style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(DateFormat.yMMMMd().format(date), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
            ]),
            const SizedBox(height: 24),
            TextField(
              controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal), textAlign: TextAlign.center,
              decoration: InputDecoration(prefixText: '₱ ', filled: true, fillColor: Colors.teal.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
              autofocus: true,
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () => _saveEntry(normalizedDate),
              child: const Text('Save Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _saveEntry(DateTime normalizedDate) async {
    final input = _amountController.text;
    if (input.isEmpty) {
      await DatabaseHelper.instance.deleteSaving(normalizedDate);
      _refreshSavings(); if (mounted) Navigator.pop(context); return;
    }
    final amount = double.tryParse(input);
    if (amount == null) return;

    final bool? shouldDeduct = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deduct from Balance?'),
        content: Text('Do you want to deduct ₱${amount.toStringAsFixed(2)} from your main balance?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No, Just Track')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.teal), onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Deduct')),
        ],
      ),
    );

    await DatabaseHelper.instance.insertSaving(normalizedDate, amount);
    if (shouldDeduct == true) {
      final expense = ExpenseItem(title: 'Savings Deposit', amount: amount, date: normalizedDate);
      await DatabaseHelper.instance.insertExpense(expense);
    }
    _refreshSavings(); if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text('Savings', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
      body: Column(children: [
        Expanded(child: Container(margin: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]), child: ClipRRect(borderRadius: BorderRadius.circular(24), child: TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1), lastDay: DateTime.utc(2030, 12, 31), focusedDay: _focusedDay, calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selected, focused) { setState(() { _selectedDay = selected; _focusedDay = focused; }); _showSavingsModal(context, selected); },
          onFormatChanged: (format) => setState(() => _calendarFormat = format), onPageChanged: (focused) => _focusedDay = focused,
          calendarBuilders: CalendarBuilders(markerBuilder: (context, date, events) {
            if (_savings.containsKey(_normalizeDate(date))) return Positioned(bottom: 4, child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green), width: 6, height: 6));
            return null;
          }),
        )))), 
        Container(margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.teal.shade600, Colors.teal.shade400]), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Total Saved", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          Text("₱${_calculateTotal().toStringAsFixed(2)}", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        ])),
        const SizedBox(height: 20),
      ]),
    );
  }
}