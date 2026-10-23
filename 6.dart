import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: ProductInventoryScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class ProductInventoryScreen extends StatefulWidget {
  const ProductInventoryScreen({super.key});

  @override
  State<ProductInventoryScreen> createState() => _ProductInventoryScreenState();
}

class _ProductInventoryScreenState extends State<ProductInventoryScreen> {
  Database? _db;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _initDB();
  }

  Future<void> _initDB() async {
    final dbDir = await getDatabasesPath();
    final path = p.join(dbDir, 'inventory.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE products (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          price REAL NOT NULL
        )
      '''),
    );
    _refreshProducts();
  }

  Future<void> _refreshProducts() async {
    if (_db == null) return;
    final data = await _db!.query('products', orderBy: 'id DESC');
    setState(() => _products = data);
  }

  void _showProductDialog({Map<String, dynamic>? product}) {
    final nameCtrl = TextEditingController(text: product?['name'] ?? '');
    final qtyCtrl = TextEditingController(text: product?['quantity']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: product?['price']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product == null ? 'Add New Product' : 'Update Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product Name')),
              TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
              TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Price (₹)'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final qty = int.tryParse(qtyCtrl.text.trim());
              final price = double.tryParse(priceCtrl.text.trim());

              if (name.isNotEmpty && qty != null && price != null) {
                if (product == null) {
                  await _db!.insert('products', {
                    'name': name,
                    'quantity': qty,
                    'price': price,
                  });
                } else {
                  await _db!.update(
                    'products',
                    {'name': name, 'quantity': qty, 'price': price},
                    where: 'id = ?',
                    whereArgs: [product['id']],
                  );
                }
                if (mounted) Navigator.pop(ctx);
                _refreshProducts();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteProduct(int id) async {
    if (_db == null) return;
    await _db!.delete('products', where: 'id = ?', whereArgs: [id]);
    _refreshProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Inventory (SQLite)')),
      body: _products.isEmpty
          ? const Center(child: Text('No products in inventory'))
          : ListView.builder(
        itemCount: _products.length,
        itemBuilder: (ctx, i) {
          final item = _products[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: CircleAvatar(
                child: Text('${item['quantity']}'),
              ),
              title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Price: ₹${item['price']} | Stock: ${item['quantity']} units'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showProductDialog(product: item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteProduct(item['id']),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}