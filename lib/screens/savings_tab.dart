import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';

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
  String _filterType = 'Month';
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

  double _calculateFilteredTotal() {
    final now = DateTime.now();
    double total = 0.0;
    _savings.forEach((date, amount) {
      bool include = false;
      if (_filterType == 'Week') {
        final startOfWeek = _normalizeDate(now.subtract(Duration(days: now.weekday - 1)));
        final endOfWeek = _normalizeDate(startOfWeek.add(const Duration(days: 6)));
        final nDate = _normalizeDate(date);
        if ((nDate.isAfter(startOfWeek) || nDate.isAtSameMomentAs(startOfWeek)) && 
            (nDate.isBefore(endOfWeek) || nDate.isAtSameMomentAs(endOfWeek))) include = true;
      } else if (_filterType == 'Month') {
        if (date.month == now.month && date.year == now.year) include = true;
      } else if (_filterType == 'Year') {
        if (date.year == now.year) include = true;
      }
      if (include) total += amount;
    });
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Text('Add Savings for ${DateFormat.MMMd().format(date)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(prefixText: '₱ ', filled: true, fillColor: Colors.teal.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              autofocus: true,
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () => _saveEntry(normalizedDate),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveEntry(DateTime normalizedDate) async {
    final input = _amountController.text;
    if (input.isNotEmpty) {
      final amount = double.tryParse(input);
      if (amount != null) await DatabaseHelper.instance.insertSaving(normalizedDate, amount);
    } else {
      await DatabaseHelper.instance.deleteSaving(normalizedDate);
    }
    _refreshSavings();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text('Savings', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1), lastDay: DateTime.utc(2030, 12, 31), focusedDay: _focusedDay, calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selected, focused) { setState(() { _selectedDay = selected; _focusedDay = focused; }); _showSavingsModal(context, selected); },
                  onFormatChanged: (format) => setState(() => _calendarFormat = format),
                  onPageChanged: (focused) => _focusedDay = focused,
                  calendarBuilders: CalendarBuilders(markerBuilder: (context, date, events) {
                    if (_savings.containsKey(_normalizeDate(date))) {
                      return Positioned(bottom: 4, child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green), width: 6, height: 6));
                    } return null;
                  }),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: ['Week', 'Month', 'Year'].map((type) => _buildFilterBtn(type)).toList()),
          ),
          const SizedBox(height: 16),
          _buildTotalCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFilterBtn(String type) {
    final isSelected = _filterType == type;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: Container(
        margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? Colors.teal : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? Colors.teal : Colors.grey.shade300)),
        child: Text(type, style: TextStyle(color: isSelected ? Colors.white : Colors.grey)),
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.teal.shade600, Colors.teal.shade400]), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text("Total Saved", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text("₱${_calculateFilteredTotal().toStringAsFixed(2)}", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
      ]),
    );
  }
}