import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: StudentHomeScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

// Model Class
class Student {
  final int? id;
  final String name;
  final String rollNo;
  final String course;

  Student({this.id, required this.name, required this.rollNo, required this.course});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rollNo': rollNo,
      'course': course,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'],
      name: map['name'],
      rollNo: map['rollNo'],
      course: map['course'],
    );
  }
}

// Database Helper Class
class StudentDatabaseHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    final dbDir = await getDatabasesPath();
    final path = p.join(dbDir, 'student_management.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE students (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          rollNo TEXT NOT NULL,
          course TEXT NOT NULL
        )
      '''),
    );
    return _database!;
  }

  static Future<int> insertStudent(Student student) async {
    final db = await database;
    return await db.insert('students', student.toMap());
  }

  static Future<List<Student>> getAllStudents() async {
    final db = await database;
    final List<Map<String, dynamic>> records = await db.query('students', orderBy: 'id DESC');
    return records.map((e) => Student.fromMap(e)).toList();
  }

  static Future<int> updateStudent(Student student) async {
    final db = await database;
    return await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  static Future<int> deleteStudent(int id) async {
    final db = await database;
    return await db.delete('students', where: 'id = ?', whereArgs: [id]);
  }
}

// Screen 1: Home Screen
class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Management System')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.school, size: 90, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'Student Records Portal',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 36),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)),
                icon: const Icon(Icons.person_add),
                label: const Text('Add New Student', style: TextStyle(fontSize: 16)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => const AddStudentScreen()),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(14)),
                icon: const Icon(Icons.list_alt),
                label: const Text('View Student Directory', style: TextStyle(fontSize: 16)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => const StudentListScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Screen 2: Add Student Screen
class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _rollCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();

  void _saveStudent() async {
    if (_formKey.currentState!.validate()) {
      final student = Student(
        name: _nameCtrl.text.trim(),
        rollNo: _rollCtrl.text.trim(),
        course: _courseCtrl.text.trim(),
      );
      await StudentDatabaseHelper.insertStudent(student);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student added successfully!')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Student')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Student Name', border: OutlineInputBorder()),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter student name' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _rollCtrl,
                decoration: const InputDecoration(labelText: 'Roll Number', border: OutlineInputBorder()),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter roll number' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _courseCtrl,
                decoration: const InputDecoration(labelText: 'Course / Department', border: OutlineInputBorder()),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter course' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saveStudent,
                  child: const Text('Submit Record', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Screen 3: Student List Screen
class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  List<Student> _studentList = [];

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  void _fetchStudents() async {
    final list = await StudentDatabaseHelper.getAllStudents();
    setState(() => _studentList = list);
  }

  void _confirmDelete(int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete the record for $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await StudentDatabaseHelper.deleteStudent(id);
              if (mounted) Navigator.pop(ctx);
              _fetchStudents();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Directory')),
      body: _studentList.isEmpty
          ? const Center(child: Text('No student records found'))
          : ListView.builder(
        itemCount: _studentList.length,
        itemBuilder: (ctx, i) {
          final student = _studentList[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : '?'),
              ),
              title: Text('${student.name} (${student.rollNo})', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Course: ${student.course}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => UpdateStudentScreen(student: student)),
                      );
                      _fetchStudents();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(student.id!, student.name),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Screen 4: Update Student Screen
class UpdateStudentScreen extends StatefulWidget {
  final Student student;
  const UpdateStudentScreen({super.key, required this.student});

  @override
  State<UpdateStudentScreen> createState() => _UpdateStudentScreenState();
}

class _UpdateStudentScreenState extends State<UpdateStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _rollCtrl;
  late TextEditingController _courseCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.student.name);
    _rollCtrl = TextEditingController(text: widget.student.rollNo);
    _courseCtrl = TextEditingController(text: widget.student.course);
  }

  void _updateStudent() async {
    if (_formKey.currentState!.validate()) {
      final updated = Student(
        id: widget.student.id,
        name: _nameCtrl.text.trim(),
        rollNo: _rollCtrl.text.trim(),
        course: _courseCtrl.text.trim(),
      );
      await StudentDatabaseHelper.updateStudent(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student details updated!')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Update Student')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Student Name', border: OutlineInputBorder()),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter student name' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _rollCtrl,
                decoration: const InputDecoration(labelText: 'Roll Number', border: OutlineInputBorder()),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter roll number' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _courseCtrl,
                decoration: const InputDecoration(labelText: 'Course / Department', border: OutlineInputBorder()),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter course' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _updateStudent,
                  child: const Text('Save Changes', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}