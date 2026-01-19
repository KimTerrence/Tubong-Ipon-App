// lib/main.dart

import 'package:flutter/material.dart';
import 'screens/savings_tab.dart';
import 'screens/expenses_tab.dart';
import 'screens/dashboard_tab.dart';
import 'screens/income_tab.dart';
import 'screens/settings_tab.dart'; // Import the new file

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finance Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 2; // Default to Dashboard (Middle)
  
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const IncomeListTab(),      // 0
      const SavingsCalendarTab(), // 1
      DashboardTab(onTabChange: _changeTab), // 2 (Dashboard)
      const ExpensesListTab(),    // 3
      const SettingsTab(),        // 4 (New Settings Tab)
    ];
  }

  void _changeTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _changeTab,
        // Make labels smaller so 5 items fit nicely
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected, 
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.attach_money), 
            selectedIcon: Icon(Icons.attach_money, color: Colors.teal),
            label: 'Income'
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: Colors.blue), 
            label: 'Savings'
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Colors.indigo), 
            label: 'Home'
          ),
          NavigationDestination(
            icon: Icon(Icons.money_off_outlined),
            selectedIcon: Icon(Icons.money_off, color: Colors.red), 
            label: 'Expenses'
          ),
          // NEW SETTINGS TAB
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: Colors.grey), 
            label: 'Settings'
          ),
        ],
      ),
    );
  }
}