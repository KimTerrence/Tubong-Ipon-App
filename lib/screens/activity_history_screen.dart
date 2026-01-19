// lib/screens/activity_history_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  List<Map<String, dynamic>> _allActivities = [];
  List<Map<String, dynamic>> _filteredActivities = [];
  bool _isLoading = true;
  String _currentFilter = 'All'; // Filters: All, Income, Expenses, Savings, Logs

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final expenses = await db.getExpenses();
    final incomes = await db.getIncomes();
    final savingsMap = await db.getSavings();
    final logs = await db.getLogs();

    List<Map<String, dynamic>> temp = [];

    // Combine everything
    for (var e in expenses) {
      temp.add({'type': 'Expenses', 'title': e.title, 'amount': e.amount, 'date': e.date});
    }
    for (var i in incomes) {
      temp.add({'type': 'Income', 'title': i['title'], 'amount': i['amount'], 'date': DateTime.parse(i['date'])});
    }
    savingsMap.forEach((date, amount) {
      temp.add({'type': 'Savings', 'title': 'Deposit', 'amount': amount, 'date': date});
    });
    for (var log in logs) {
      temp.add({'type': 'Logs', 'title': log['title'], 'amount': log['amount'], 'date': DateTime.parse(log['date'])});
    }

    // Sort by date (newest first)
    temp.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    if (mounted) {
      setState(() {
        _allActivities = temp;
        _isLoading = false;
        _applyFilter();
      });
    }
  }

  void _applyFilter() {
    setState(() {
      if (_currentFilter == 'All') {
        _filteredActivities = _allActivities;
      } else {
        _filteredActivities = _allActivities.where((item) => item['type'] == _currentFilter).toList();
      }
    });
  }

  void _setFilter(String filter) {
    _currentFilter = filter;
    _applyFilter();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Activity History', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          // FILTER CHIPS
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('All', Colors.black87),
                _buildFilterChip('Income', Colors.teal),
                _buildFilterChip('Expenses', Colors.redAccent),
                _buildFilterChip('Savings', Colors.blue),
                _buildFilterChip('Logs', Colors.grey),
              ],
            ),
          ),
          
          // LIST
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : _filteredActivities.isEmpty
                ? Center(child: Text("No records found", style: TextStyle(color: Colors.grey.shade400)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredActivities.length,
                    itemBuilder: (context, index) {
                      final item = _filteredActivities[index];
                      return _buildActivityItem(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, Color color) {
    bool isSelected = _currentFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: color.withOpacity(0.2),
        labelStyle: TextStyle(
          color: isSelected ? color : Colors.grey.shade600, 
          fontWeight: FontWeight.bold
        ),
        backgroundColor: Colors.white,
        onSelected: (bool selected) => _setFilter(label),
        side: BorderSide(color: isSelected ? color : Colors.grey.shade300),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> item) {
    String type = item['type'];
    bool isExpense = type == 'Expenses';
    bool isDeletion = type == 'Logs';
    
    IconData icon;
    Color color;
    String sign;

    if (type == 'Income') {
      icon = Icons.attach_money;
      color = Colors.teal;
      sign = '+';
    } else if (type == 'Savings') {
      icon = Icons.savings_outlined;
      color = Colors.blue;
      sign = '+';
    } else if (isExpense) {
      icon = Icons.shopping_bag_outlined;
      color = Colors.redAccent;
      sign = '-';
    } else {
      icon = Icons.delete_outline;
      color = Colors.grey;
      sign = '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['title'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: isDeletion ? TextDecoration.lineThrough : null, color: isDeletion ? Colors.grey : Colors.black87)),
                const SizedBox(height: 4),
                Text(DateFormat.yMMMd().format(item['date']), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("$sign₱${(item['amount'] as double).toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
              Text(type, style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }
}