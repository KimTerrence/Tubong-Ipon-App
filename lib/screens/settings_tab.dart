// lib/screens/settings_tab.dart

import 'dart:io'; // Needed for File operations
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart'; // To get temporary folder
import '../services/database_helper.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  // --- LOGIC: EXPORT DATA TO CSV ---
  Future<void> _exportData(BuildContext context) async {
    // 1. Request Permission
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }

    // Double check for Android 11+ (Manage External Storage)
    if (await Permission.manageExternalStorage.status.isDenied) {
       await Permission.manageExternalStorage.request();
    }

    try {
      showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));

      // 2. Fetch Data
      final db = DatabaseHelper.instance;
      final expenses = await db.getExpenses();
      final incomes = await db.getIncomes();
      final savings = await db.getSavings();

      String csvData = "Date,Type,Description,Amount\n";

      for (var item in incomes) {
        String date = item['date'].toString().substring(0, 10);
        csvData += "$date,Income,${item['title']},${item['amount']}\n";
      }
      for (var item in expenses) {
        String date = item.date.toIso8601String().substring(0, 10);
        csvData += "$date,Expense,${item.title},-${item.amount}\n";
      }
      savings.forEach((date, amount) {
        String dateStr = date.toIso8601String().substring(0, 10);
        csvData += "$dateStr,Savings,Deposit,${amount}\n";
      });

      // 3. Save to DOWNLOADS Folder (Android specific)
      // This path is specific to Android Downloads
      Directory generalDownloadDir = Directory('/storage/emulated/0/Download'); 
      
      // Fallback if that path doesn't exist (e.g. some emulators)
      if (!await generalDownloadDir.exists()) {
         generalDownloadDir = await getExternalStorageDirectory() ?? Directory('/storage/emulated/0/Download');
      }

      final String path = "${generalDownloadDir.path}/finance_tracker_backup.csv";
      final File file = File(path);
      await file.writeAsString(csvData);

      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Success! Saved to: $path"), 
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          )
        );
      }

    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }
  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset App Data?"),
        content: const Text("This will permanently delete all your Income, Expenses, Savings, and Logs. This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await DatabaseHelper.instance.clearAllData();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("All data has been wiped."), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("Reset Everything"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Section 1: General
          const Text("General", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          _buildSettingsTile(
            icon: Icons.notifications_outlined,
            color: Colors.orange,
            title: "Notifications",
            subtitle: "Manage daily reminders",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Feature coming soon!")));
            },
          ),
          _buildSettingsTile(
            icon: Icons.currency_exchange,
            color: Colors.green,
            title: "Currency",
            subtitle: "Current: Philippine Peso (₱)",
            onTap: () {},
          ),

          const SizedBox(height: 30),

          // Section 2: Data Management
          const Text("Data Management", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          
          // NEW: Export Button 
          _buildSettingsTile(
            icon: Icons.download_rounded,
            color: Colors.blue,
            title: "Export Data",
            subtitle: "Save history as CSV (Excel)",
            onTap: () => _exportData(context),
          ),
          
          _buildSettingsTile(
            icon: Icons.delete_forever_rounded,
            color: Colors.red,
            title: "Reset All Data",
            subtitle: "Clear all transactions and history",
            onTap: () => _confirmReset(context),
          ),

          const SizedBox(height: 30),

          // Section 3: About
          const Center(
            child: Column(
              children: [
                Icon(Icons.account_balance_wallet, size: 40, color: Colors.blueGrey),
                SizedBox(height: 10),
                Text("Tubong Finance Tracker v1.0", style: TextStyle(color: Colors.grey)),
                Text("By: Kim Terrence", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}