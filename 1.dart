import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: ContactBookScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class ContactBookScreen extends StatefulWidget {
  const ContactBookScreen({super.key});

  @override
  State<ContactBookScreen> createState() => _ContactBookScreenState();
}

class _ContactBookScreenState extends State<ContactBookScreen> {
  Database? _db;
  List<Map<String, dynamic>> _contacts = [];

  @override
  void initState() {
    super.initState();
    _initDB();
  }

  Future<void> _initDB() async {
    final dbDir = await getDatabasesPath();
    final path = p.join(dbDir, 'contacts.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => db.execute(
        'CREATE TABLE contacts (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, phone TEXT)',
      ),
    );
    _loadContacts();
  }

  Future<void> _loadContacts({String query = ''}) async {
    if (_db == null) return;
    List<Map<String, dynamic>> result;
    if (query.isEmpty) {
      result = await _db!.query('contacts');
    } else {
      result = await _db!.rawQuery('SELECT * FROM contacts WHERE name LIKE ?', ['%$query%']);
    }
    setState(() => _contacts = result);
  }

  void _addContactDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                await _db!.insert('contacts', {'name': nameCtrl.text, 'phone': phoneCtrl.text});
                if (mounted) Navigator.pop(ctx);
                _loadContacts();
              }
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  void _confirmDelete(int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await _db!.delete('contacts', where: 'id = ?', whereArgs: [id]);
              if (mounted) Navigator.pop(ctx);
              _loadContacts();
            },
            child: const Text('Delete', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Book (SQLite)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search contacts (LIKE query)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => _loadContacts(query: val),
            ),
          ),
          Expanded(
            child: _contacts.isEmpty
                ? const Center(child: Text('No contacts found'))
                : ListView.builder(
              itemCount: _contacts.length,
              itemBuilder: (ctx, i) => ListTile(
                leading: CircleAvatar(
                  child: Text(_contacts[i]['name'].isNotEmpty ? _contacts[i]['name'][0].toUpperCase() : '?'),
                ),
                title: Text(_contacts[i]['name']),
                subtitle: Text(_contacts[i]['phone']),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDelete(_contacts[i]['id'], _contacts[i]['name']),
                ),
              ),
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addContactDialog,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}