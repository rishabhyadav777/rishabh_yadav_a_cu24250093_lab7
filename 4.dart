import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: TodoScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  Database? _db;
  List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    _initDB();
  }

  Future<void> _initDB() async {
    final dbDir = await getDatabasesPath();
    final path = p.join(dbDir, 'todo.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => db.execute(
        'CREATE TABLE todos (id INTEGER PRIMARY KEY AUTOINCREMENT, task TEXT, isDone INTEGER)',
      ),
    );
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    if (_db == null) return;
    final data = await _db!.query('todos', orderBy: 'id DESC');
    setState(() => _tasks = data);
  }

  void _toggleTask(int id, int currentStatus) async {
    if (_db == null) return;
    await _db!.update(
      'todos',
      {'isDone': currentStatus == 1 ? 0 : 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    _loadTasks();
  }

  void _deleteTask(int id) async {
    if (_db == null) return;
    await _db!.delete('todos', where: 'id = ?', whereArgs: [id]);
    _loadTasks();
  }

  void _addTaskDialog() {
    final taskCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Task'),
        content: TextField(
          controller: taskCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Task Description'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (taskCtrl.text.trim().isNotEmpty) {
                await _db!.insert('todos', {
                  'task': taskCtrl.text.trim(),
                  'isDone': 0,
                });
                if (mounted) Navigator.pop(ctx);
                _loadTasks();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('To-Do SQLite (Checkbox)')),
      body: _tasks.isEmpty
          ? const Center(child: Text('No tasks available. Tap + to add one.'))
          : ListView.builder(
        itemCount: _tasks.length,
        itemBuilder: (ctx, i) {
          final isCompleted = _tasks[i]['isDone'] == 1;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: ListTile(
              leading: Checkbox(
                value: isCompleted,
                onChanged: (_) => _toggleTask(_tasks[i]['id'], _tasks[i]['isDone']),
              ),
              title: Text(
                _tasks[i]['task'],
                style: TextStyle(
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  color: isCompleted ? Colors.grey : Colors.black87,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteTask(_tasks[i]['id']),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}