import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: ExpenseTrackerScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class ExpenseTrackerScreen extends StatefulWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> {
  Database? _db;
  List<Map<String, dynamic>> _expenses = [];
  double _totalExpense = 0.0;

  @override
  void initState() {
    super.initState();
    _initDB();
  }

  Future<void> _initDB() async {
    final dbDir = await getDatabasesPath();
    final path = p.join(dbDir, 'expenses.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => db.execute(
        'CREATE TABLE expenses (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL)',
      ),
    );
    _refreshExpenses();
  }

  Future<void> _refreshExpenses() async {
    if (_db == null) return;

    // Fetch all rows
    final data = await _db!.query('expenses', orderBy: 'id DESC');

    // Calculate sum using SQL SUM function
    final sumResult = await _db!.rawQuery('SELECT SUM(amount) as total FROM expenses');
    final total = (sumResult.first['total'] as num?)?.toDouble() ?? 0.0;

    setState(() {
      _expenses = data;
      _totalExpense = total;
    });
  }

  void _addExpenseDialog() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title / Description')),
            TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount (₹)'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim());
              if (titleCtrl.text.trim().isNotEmpty && amount != null) {
                await _db!.insert('expenses', {
                  'title': titleCtrl.text.trim(),
                  'amount': amount,
                });
                if (mounted) Navigator.pop(ctx);
                _refreshExpenses();
              }
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  void _deleteExpense(int id) async {
    if (_db == null) return;
    await _db!.delete('expenses', where: 'id = ?', whereArgs: [id]);
    _refreshExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expense Tracker (SQLite SUM)')),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Expense:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    '₹${_totalExpense.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _expenses.isEmpty
                ? const Center(child: Text('No expenses recorded'))
                : ListView.builder(
              itemCount: _expenses.length,
              itemBuilder: (ctx, i) => ListTile(
                leading: const CircleAvatar(child: Icon(Icons.currency_rupee)),
                title: Text(_expenses[i]['title'], style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('ID: ${_expenses[i]['id']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('₹${(_expenses[i]['amount'] as num).toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteExpense(_expenses[i]['id']),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExpenseDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}