// lib/screens/dashboard_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';

class DashboardTab extends StatefulWidget {
  final Function(int) onTabChange;

  const DashboardTab({super.key, required this.onTabChange});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  // Updated totals structure
  Map<String, double> _totals = {'income': 0.0, 'expenses': 0.0, 'balance': 0.0, 'savings': 0.0};
  List<Map<String, dynamic>> _recentTransactions = [];
  bool _isLoading = true;

  // Controllers for Adding Income
  final TextEditingController _incomeTitleController = TextEditingController();
  final TextEditingController _incomeAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final db = DatabaseHelper.instance;
    final totals = await db.getTotals();
    final expenses = await db.getExpenses();
    final incomes = await db.getIncomes(); // Get Income List
    
    List<Map<String, dynamic>> combinedList = [];
    
    // Add Expenses to List
    for (var e in expenses) {
      combinedList.add({
        'type': 'expense',
        'title': e.title,
        'amount': e.amount,
        'date': e.date,
      });
    }

    // Add Income to List
    for (var i in incomes) {
      combinedList.add({
        'type': 'income',
        'title': i['title'],
        'amount': i['amount'],
        'date': DateTime.parse(i['date']),
      });
    }

    // Sort by Date (Newest First) and take top 5
    combinedList.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    final recent = combinedList.take(5).toList();

    if (mounted) {
      setState(() {
        _totals = totals;
        _recentTransactions = recent;
        _isLoading = false;
      });
    }
  }

  // --- LOGIC: ADD INCOME POPUP ---
  void _showAddIncomeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Income"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _incomeTitleController,
              decoration: const InputDecoration(labelText: "Source (e.g. Salary, Sales)"),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _incomeAmountController,
              decoration: const InputDecoration(labelText: "Amount", prefixText: "₱ "),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          FilledButton(
            onPressed: () async {
              if (_incomeTitleController.text.isNotEmpty && _incomeAmountController.text.isNotEmpty) {
                 final amount = double.tryParse(_incomeAmountController.text);
                 if (amount != null) {
                   await DatabaseHelper.instance.insertIncome(_incomeTitleController.text, amount);
                   _incomeTitleController.clear();
                   _incomeAmountController.clear();
                   Navigator.pop(context);
                   _loadAllData(); // Refresh UI
                 }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text("Add"),
          )
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getGreeting(), style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const Text("My Wallet", style: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. MAIN BALANCE (Income - Expenses)
                _buildNetBalanceCard(),

                const SizedBox(height: 20),

                // 2. SPLIT INCOME VS EXPENSE CARDS
                Row(
                  children: [
                    Expanded(child: _buildStatCard("Income", _totals['income']!, Colors.teal, Icons.arrow_downward)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatCard("Expenses", _totals['expenses']!, Colors.redAccent, Icons.arrow_upward)),
                  ],
                ),

                const SizedBox(height: 25),

                // 3. QUICK ACTIONS
                const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    // CHANGED: This now opens the Income Dialog instead of switching tabs
                    Expanded(child: _buildActionBtn(Icons.attach_money_rounded, Colors.teal, "Add Income", _showAddIncomeDialog)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildActionBtn(Icons.money_off_rounded, Colors.redAccent, "Add Expense", () => widget.onTabChange(2))),
                  ],
                ),

                const SizedBox(height: 30),

                // 4. RECENT TRANSACTIONS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    // You can add a view all logic later
                  ],
                ),
                _buildRecentTransactionsList(),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildNetBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade900, Colors.blue.shade700],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.blue.shade900.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text("Total Balance (Income - Expenses)", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 10),
          Text(
            "₱${_totals['balance']!.toStringAsFixed(2)}", 
            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          // Small badge showing "Saved" amount from the Calendar (Optional)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
            child: Text(
              "Savings: ₱${_totals['savings']!.toStringAsFixed(0)}", 
              style: const TextStyle(color: Colors.white, fontSize: 12)
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "₱${amount.toStringAsFixed(0)}", 
            style: const TextStyle(color: Colors.black87, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, Color color, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsList() {
    if (_recentTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Text("No recent activity", style: TextStyle(color: Colors.grey.shade400)),
      );
    }

    return Column(
      children: _recentTransactions.map((tx) {
        bool isExpense = tx['type'] == 'expense';
        // Income = Teal, Expense = Red
        Color iconBg = isExpense ? const Color(0xFFFFE5E5) : const Color(0xFFE0F7FA);
        Color iconColor = isExpense ? const Color(0xFFE53935) : const Color(0xFF00897B);
        String sign = isExpense ? '-' : '+';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.03), blurRadius: 5)],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(16)),
                child: Icon(
                  isExpense ? Icons.shopping_bag : Icons.attach_money,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(DateFormat.MMMd().format(tx['date']), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                "$sign₱${(tx['amount'] as double).toStringAsFixed(0)}",
                style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}