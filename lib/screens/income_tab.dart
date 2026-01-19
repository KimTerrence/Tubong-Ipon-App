// lib/screens/income_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';

class IncomeListTab extends StatefulWidget {
  const IncomeListTab({super.key});

  @override
  State<IncomeListTab> createState() => _IncomeListTabState();
}

class _IncomeListTabState extends State<IncomeListTab> {
  final List<Map<String, dynamic>> _incomes = [];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  
  String _filterType = 'Month'; // Default filter

  @override
  void initState() {
    super.initState();
    _refreshIncomes();
  }

  Future<void> _refreshIncomes() async {
    final data = await DatabaseHelper.instance.getIncomes();
    if (mounted) {
      setState(() {
        _incomes.clear();
        _incomes.addAll(data);
      });
    }
  }

  double _calculateFilteredTotal() {
    final now = DateTime.now();
    double total = 0.0;

    for (var item in _incomes) {
      bool include = false;
      final date = DateTime.parse(item['date']);

      if (_filterType == 'Today') {
        if (date.year == now.year && date.month == now.month && date.day == now.day) include = true;
      } else if (_filterType == 'Week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        final nDate = DateTime(date.year, date.month, date.day);
        final nStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final nEnd = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);
        if ((nDate.isAfter(nStart) || nDate.isAtSameMomentAs(nStart)) && 
            (nDate.isBefore(nEnd) || nDate.isAtSameMomentAs(nEnd))) include = true;
      } else if (_filterType == 'Month') {
        if (date.month == now.month && date.year == now.year) include = true;
      } else if (_filterType == 'Year') {
        if (date.year == now.year) include = true;
      }

      if (include) {
        total += item['amount'] as double;
      }
    }
    return total;
  }

  void _addIncome() {
    _titleController.clear();
    _amountController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Income', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Source (e.g. Salary)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '₱ ', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: _saveIncome,
            style: FilledButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _saveIncome() async {
    if (_titleController.text.isNotEmpty && _amountController.text.isNotEmpty) {
      final amount = double.tryParse(_amountController.text);
      if (amount != null) {
        await DatabaseHelper.instance.insertIncome(_titleController.text, amount);
        _refreshIncomes();
        if (mounted) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Income', style: TextStyle(fontWeight: FontWeight.bold)), 
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildTotalCard(),

          // Filter Buttons
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['Today', 'Week', 'Month', 'Year'].map((type) => _buildFilterBtn(type)).toList(),
            ),
          ),

          Expanded(
            child: _incomes.isEmpty
                ? const Center(child: Text("No income records", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _incomes.length,
                    itemBuilder: (context, index) {
                      final item = _incomes[index];
                      return Dismissible(
                        key: ValueKey(item['id']),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) async {
                          await DatabaseHelper.instance.deleteIncome(item['id']);
                          setState(() => _incomes.removeAt(index));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Income deleted'), backgroundColor: Colors.teal),
                          );
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(16)),
                          child: Icon(Icons.delete, color: Colors.red.shade700, size: 30),
                        ),
                        child: Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal.shade50,
                              child: const Icon(Icons.attach_money, color: Colors.teal),
                            ),
                            title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(DateFormat.yMMMd().format(DateTime.parse(item['date']))),
                            trailing: Text(
                              "+₱${(item['amount'] as double).toStringAsFixed(2)}",
                              style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addIncome,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade700, Colors.teal.shade400],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                child: const Icon(Icons.calendar_today, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Text("Total Income ($_filterType)", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "₱${_calculateFilteredTotal().toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBtn(String type) {
    final isSelected = _filterType == type;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.teal : Colors.grey.shade300),
          boxShadow: isSelected ? [BoxShadow(color: Colors.teal.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Center(
          child: Text(
            type,
            style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}