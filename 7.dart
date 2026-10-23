import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: ShoppingCartScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class ShoppingCartScreen extends StatefulWidget {
  const ShoppingCartScreen({super.key});

  @override
  State<ShoppingCartScreen> createState() => _ShoppingCartScreenState();
}

class _ShoppingCartScreenState extends State<ShoppingCartScreen> {
  Database? _db;
  List<Map<String, dynamic>> _cartItems = [];
  double _totalCartPrice = 0.0;

  @override
  void initState() {
    super.initState();
    _initDB();
  }

  Future<void> _initDB() async {
    final dbDir = await getDatabasesPath();
    final path = p.join(dbDir, 'shopping_cart.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE cart (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          item_name TEXT NOT NULL,
          price REAL NOT NULL,
          quantity INTEGER NOT NULL
        )
      '''),
    );
    _refreshCart();
  }

  Future<void> _refreshCart() async {
    if (_db == null) return;

    // Fetch all cart items
    final data = await _db!.query('cart', orderBy: 'id DESC');

    // Calculate total price using raw SQL: SUM(price * quantity)
    final sumResult = await _db!.rawQuery('SELECT SUM(price * quantity) as total FROM cart');
    final total = (sumResult.first['total'] as num?)?.toDouble() ?? 0.0;

    setState(() {
      _cartItems = data;
      _totalCartPrice = total;
    });
  }

  void _addItemDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Cart Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item Name')),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Price per Unit (₹)'), keyboardType: TextInputType.number),
            TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim());
              final qty = int.tryParse(qtyCtrl.text.trim());

              if (name.isNotEmpty && price != null && qty != null) {
                await _db!.insert('cart', {
                  'item_name': name,
                  'price': price,
                  'quantity': qty,
                });
                if (mounted) Navigator.pop(ctx);
                _refreshCart();
              }
            },
            child: const Text('Add to Cart'),
          )
        ],
      ),
    );
  }

  void _deleteItem(int id) async {
    if (_db == null) return;
    await _db!.delete('cart', where: 'id = ?', whereArgs: [id]);
    _refreshCart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shopping Cart (SQLite)')),
      body: Column(
        children: [
          Expanded(
            child: _cartItems.isEmpty
                ? const Center(child: Text('Your cart is empty'))
                : ListView.builder(
              itemCount: _cartItems.length,
              itemBuilder: (ctx, i) {
                final item = _cartItems[i];
                final subtotal = (item['price'] as num) * (item['quantity'] as num);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text('${item['quantity']}x'),
                    ),
                    title: Text(item['item_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Rate: ₹${item['price']} | Subtotal: ₹${subtotal.toStringAsFixed(2)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteItem(item['id']),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border(top: BorderSide(color: Colors.green.shade200, width: 1.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Grand Total:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹${_totalCartPrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60.0),
        child: FloatingActionButton(
          onPressed: _addItemDialog,
          child: const Icon(Icons.add_shopping_cart),
        ),
      ),
    );
  }
}