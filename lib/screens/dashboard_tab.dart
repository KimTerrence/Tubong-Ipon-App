// lib/screens/dashboard_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import 'activity_history_screen.dart'; 

class DashboardTab extends StatefulWidget {
  final Function(int) onTabChange;
  const DashboardTab({super.key, required this.onTabChange});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  Map<String, double> _totals = {'savings': 0.0, 'expenses': 0.0, 'balance': 0.0, 'income': 0.0};
  
  // ANALYTICS DATA
  List<Map<String, dynamic>> _weeklySpending = []; 
  List<Map<String, dynamic>> _topExpenses = []; // NEW: Top spending categories
  double _dailyAverage = 0.0; // NEW: Daily average
  
  bool _isLoading = true;
  final TextEditingController _incomeTitle = TextEditingController();
  final TextEditingController _incomeAmount = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final db = DatabaseHelper.instance;
    final totals = await db.getTotals();
    final expenses = await db.getExpenses();
    
    // 1. CALCULATE WEEKLY SPENDING (Last 7 Days)
    List<Map<String, dynamic>> last7Days = [];
    DateTime now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      DateTime day = now.subtract(Duration(days: i));
      String dayLabel = DateFormat.E().format(day); // Mon, Tue
      double dailyTotal = 0;
      for (var e in expenses) {
        if (e.date.year == day.year && e.date.month == day.month && e.date.day == day.day) {
          dailyTotal += e.amount;
        }
      }
      last7Days.add({'day': dayLabel, 'amount': dailyTotal});
    }

    // 2. NEW: CALCULATE TOP EXPENSES (Group by Title)
    Map<String, double> expenseMap = {};
    for (var e in expenses) {
      // Normalize title (lowercase, trim) to group "Food " and "food"
      String key = e.title.trim(); 
      if (key.isEmpty) key = "Other";
      // Capitalize first letter for display
      key = key[0].toUpperCase() + key.substring(1);
      
      expenseMap[key] = (expenseMap[key] ?? 0) + e.amount;
    }
    
    // Convert to List and Sort
    List<Map<String, dynamic>> sortedExpenses = expenseMap.entries
      .map((e) => {'title': e.key, 'amount': e.value})
      .toList();
    sortedExpenses.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double)); // Highest first
    List<Map<String, dynamic>> top3 = sortedExpenses.take(3).toList();

    // 3. NEW: CALCULATE DAILY AVERAGE (This Month)
    int daysPassed = now.day; // e.g., if it's Jan 15, divide by 15
    if (daysPassed == 0) daysPassed = 1;
    
    // Filter expenses for THIS month only
    double monthlyExpenseSum = 0;
    for (var e in expenses) {
      if (e.date.year == now.year && e.date.month == now.month) {
        monthlyExpenseSum += e.amount;
      }
    }
    double dailyAvg = monthlyExpenseSum / daysPassed;

    if (mounted) {
      setState(() {
        _totals = totals;
        _weeklySpending = last7Days;
        _topExpenses = top3;
        _dailyAverage = dailyAvg;
        _isLoading = false;
      });
    }
  }

  void _showAddIncomeDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("Add Income", style: TextStyle(fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _incomeTitle, decoration: const InputDecoration(labelText: "Source", hintText: "e.g. Salary"), textCapitalization: TextCapitalization.sentences),
        const SizedBox(height: 10),
        TextField(controller: _incomeAmount, decoration: const InputDecoration(labelText: "Amount", prefixText: "₱ "), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        FilledButton(onPressed: () async {
           if (_incomeTitle.text.isNotEmpty && _incomeAmount.text.isNotEmpty) {
             final amount = double.tryParse(_incomeAmount.text);
             if (amount != null) {
               await DatabaseHelper.instance.insertIncome(_incomeTitle.text, amount);
               _incomeTitle.clear(); _incomeAmount.clear();
               Navigator.pop(context);
               _loadAllData();
             }
           }
        }, style: FilledButton.styleFrom(backgroundColor: Colors.teal), child: const Text("Add"))
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    String currentDate = DateFormat.MMMMEEEEd().format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(DateTime.now().hour < 12 ? 'Good Morning,' : 'Good Evening,', 
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500)),
          Text(currentDate, 
            style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        centerTitle: false, backgroundColor: Colors.transparent, elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Material(
              color: Colors.white, borderRadius: BorderRadius.circular(14), elevation: 2, shadowColor: Colors.black12,
              child: InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ActivityHistoryScreen())).then((_) => _loadAllData());
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  child: const Icon(Icons.history_rounded, color: Colors.blueGrey),
                ),
              ),
            ),
          )
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          
          _buildNetBalanceCard(),
          const SizedBox(height: 24),
          
          // ROW: Daily Average & Budget Status
          Row(
            children: [
              Expanded(child: _buildDailyAverageCard()),
              const SizedBox(width: 16),
              Expanded(child: _buildBudgetHealthCard()), // Simplified Budget Card
            ],
          ),
          const SizedBox(height: 24),

          // CHART: Weekly Trend
          _buildWeeklySpendingChart(),
          const SizedBox(height: 24),

          // LIST: Top Expenses
          if (_topExpenses.isNotEmpty) ...[
            _buildTopExpensesList(),
            const SizedBox(height: 24),
          ],
          
          // STATS ROW
          Row(children: [
            Expanded(child: _buildStatCard("Income", _totals['income']!, Colors.teal, Icons.arrow_downward_rounded)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard("Expenses", _totals['expenses']!, Colors.redAccent, Icons.arrow_upward_rounded)),
          ]),
          
          const SizedBox(height: 32),
          
          // ACTIONS
          Row(children: [
            Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)),
            const Spacer(),
            Icon(Icons.bolt_rounded, color: Colors.amber.shade600, size: 22), 
          ]),
          const SizedBox(height: 16),
          
          Row(children: [
            Expanded(child: _buildActionBtn(Icons.attach_money_rounded, Colors.teal, "Add Income", _showAddIncomeDialog)),
            const SizedBox(width: 16),
            Expanded(child: _buildActionBtn(Icons.money_off_rounded, Colors.redAccent, "Add Expense", () => widget.onTabChange(2))),
          ]),
          
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  // --- WIDGETS ---

  // 1. DAILY AVERAGE CARD
  Widget _buildDailyAverageCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Daily Average", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("₱${_dailyAverage.toStringAsFixed(0)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 4),
        const Text("this month", style: TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
    );
  }

  // 2. COMPACT BUDGET CARD
  Widget _buildBudgetHealthCard() {
    double income = _totals['income'] ?? 1.0;
    if (income <= 0) income = 1.0;
    double expenses = _totals['expenses'] ?? 0.0;
    double percentLeft = ((income - expenses) / income).clamp(0.0, 1.0);
    
    Color color = percentLeft > 0.5 ? Colors.green : (percentLeft > 0.2 ? Colors.orange : Colors.red);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Budget Left", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("${(percentLeft * 100).toStringAsFixed(0)}%", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: percentLeft, minHeight: 4, backgroundColor: Colors.grey.shade100, valueColor: AlwaysStoppedAnimation(color))),
      ]),
    );
  }

  // 3. TOP EXPENSES LIST
  Widget _buildTopExpensesList() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Top Spending", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey.shade800)),
            const Icon(Icons.pie_chart_rounded, color: Colors.grey, size: 20),
          ]),
          const SizedBox(height: 16),
          ..._topExpenses.map((item) {
            double amount = item['amount'];
            double totalExp = _totals['expenses'] == 0 ? 1 : _totals['expenses']!;
            double percent = (amount / totalExp).clamp(0.0, 1.0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text(item['title'][0], style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade400))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text("₱${amount.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: percent, minHeight: 6, backgroundColor: Colors.grey.shade100, valueColor: AlwaysStoppedAnimation(Colors.red.shade300))),
                    ]),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildWeeklySpendingChart() {
    double maxSpend = 0;
    for (var day in _weeklySpending) { if (day['amount'] > maxSpend) maxSpend = day['amount']; }
    if (maxSpend == 0) maxSpend = 1;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Last 7 Days", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey.shade800)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end,
          children: _weeklySpending.map((dayData) {
            double amount = dayData['amount'];
            double heightFactor = amount / maxSpend;
            bool isHighest = amount == maxSpend && amount > 0;
            return Column(children: [
              Container(width: 12, height: 80 * heightFactor + 4, decoration: BoxDecoration(color: isHighest ? Colors.redAccent : Colors.blueGrey.shade100, borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 8),
              Text(dayData['day'][0], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isHighest ? Colors.redAccent : Colors.grey)),
            ]);
          }).toList(),
        )
      ]),
    );
  }

  Widget _buildNetBalanceCard() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E3C72), Color(0xFF2A5298)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: const Color(0xFF1E3C72).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Stack(
        children: [
          Positioned(top: -40, right: -40, child: Container(width: 200, height: 200, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle))),
          Positioned(bottom: -40, left: -20, child: Container(width: 150, height: 150, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle))),
          Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("Total Net Balance", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)), child: const Text("PHP", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))
              ]),
              Text("₱${_totals['balance']!.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: -1)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)), child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.savings_rounded, color: Colors.tealAccent, size: 18),
                const SizedBox(width: 8),
                Text("Savings Vault: ", style: TextStyle(color: Colors.blue.shade100, fontSize: 13)),
                Text("₱${_totals['savings']!.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ]))
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
        const SizedBox(height: 16),
        Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, child: Text("₱${amount.toStringAsFixed(0)}", style: TextStyle(color: Colors.blueGrey.shade900, fontSize: 22, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Widget _buildActionBtn(IconData icon, Color color, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white, borderRadius: BorderRadius.circular(24), elevation: 0,
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(24), splashColor: color.withOpacity(0.1), highlightColor: color.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade100, width: 1.5), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
          child: Column(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.08), shape: BoxShape.circle), child: Icon(icon, color: color, size: 28)), 
            const SizedBox(height: 12), 
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey.shade800))
          ]),
        ),
      ),
    );
  }
}