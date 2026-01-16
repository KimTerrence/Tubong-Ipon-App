import 'package:flutter/material.dart';
import 'screens/savings_tab.dart';
import 'screens/expenses_tab.dart';
import 'screens/dashboard_tab.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Required for database
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
  int _selectedIndex = 1; // Default to Dashboard (Middle)

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const SavingsCalendarTab(),
      DashboardTab(onTabChange: _changeTab), // Pass callback
      const ExpensesListTab(),
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
      // IndexedStack keeps pages alive so you don't lose scroll position
      // remove 'IndexedStack' and use '_pages[_selectedIndex]' if you prefer reloading data every switch
      body: _pages[_selectedIndex], 
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _changeTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: Colors.teal),
            label: 'Savings',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Colors.blue),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.money_off_outlined),
            selectedIcon: Icon(Icons.money_off, color: Colors.red),
            label: 'Expenses',
          ),
        ],
      ),
    );
  }
}