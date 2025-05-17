import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:typed_data';
import 'admin_dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_settings.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({Key? key}) : super(key: key);

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    const AdminDashboardStatistics(),
    _WorkersView(),
    const AdminSettingsPage(),
  ];

  void _onNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0
              ? 'Dashboard'
              : _selectedIndex == 1
                  ? 'Workers'
                  : 'Settings',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color.fromARGB(221, 255, 255, 255),
          ),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 1,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavTapped,
        backgroundColor: Colors.white,
        elevation: 8,
        indicatorColor: Colors.deepPurple[50],
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Workers',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// Minimalist Dashboard Page
class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dashboard, color: Colors.deepPurple, size: 48),
              const SizedBox(height: 16),
              Text(
                'Welcome, Admin!',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage attendance, workers, and more.',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Workers Management Tab
class _WorkersView extends StatefulWidget {
  const _WorkersView();

  @override
  State<_WorkersView> createState() => _WorkersViewState();
}

class _WorkersViewState extends State<_WorkersView> {
  String _search = '';
  bool _loading = false;
  String? _message;

  Future<void> _addWorkerDialog(
      {String? existingId, String? existingName}) async {
    final controller = TextEditingController(text: existingName ?? '');
    final isEdit = existingId != null;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Worker' : 'Add Worker'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Worker Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _loading = true);

      try {
        if (isEdit) {
          await FirebaseFirestore.instance
              .collection('workers')
              .doc(existingId)
              .update({'name': result});
        } else {
          await FirebaseFirestore.instance
              .collection('workers')
              .add({'name': result});
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isEdit ? Icons.edit : Icons.check_circle,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isEdit
                        ? 'Worker updated!'
                        : 'Worker "${result.trim()}" added!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: isEdit ? Colors.blue[700] : Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            elevation: 6,
          ),
        );
      } catch (e) {
        setState(() {
          _message = 'Error: $e';
        });
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteWorker(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Worker'),
        content: const Text('Are you sure you want to delete this worker?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[100],
              foregroundColor: Colors.red[900],
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('workers')
          .doc(docId)
          .delete();
      setState(() {
        _message = 'Worker deleted!';
      });
    }
  }

  Future<void> _uploadExcel() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true, // Ensure bytes are loaded
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.first.bytes == null) {
        setState(() {
          _loading = false;
          _message = 'No file selected or file is empty.';
        });
        return;
      }

      final Uint8List fileBytes = result.files.first.bytes!;
      final excel = Excel.decodeBytes(fileBytes);

      final List<String> workerNames = [];

      // Process only the first sheet
      final firstSheet = excel.tables.values.first;
      for (int rowIdx = 1; rowIdx < firstSheet.maxRows; rowIdx++) {
        var row = firstSheet.row(rowIdx);
        if (row.isNotEmpty) {
          var cell = row[0]; // Column A
          if (cell?.value != null && cell!.value.toString().trim().isNotEmpty) {
            workerNames.add(cell.value.toString().trim());
          }
        }
      }

      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance.collection('workers');

      for (final name in workerNames) {
        final docRef = collection.doc(); // Use auto-generated ID
        batch.set(docRef, {
          'name': name,
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      setState(() {
        _loading = false;
        _message = 'Uploaded ${workerNames.length} workers!';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _message = 'Error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top controls
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search workers...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (v) =>
                      setState(() => _search = v.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: "Add Worker",
                child: Material(
                  color: Colors.deepPurple,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.person_add, color: Colors.white),
                    onPressed: _loading ? null : () => _addWorkerDialog(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: "Upload Excel",
                child: Material(
                  color: Colors.deepPurple[100],
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon:
                        const Icon(Icons.upload_file, color: Colors.deepPurple),
                    onPressed: _loading ? null : _uploadExcel,
                  ),
                ),
              ),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: LinearProgressIndicator(),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                _message!,
                style: const TextStyle(color: Colors.green, fontSize: 16),
              ),
            ),
          const SizedBox(height: 6),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('workers')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs
                    .where((doc) =>
                        _search.isEmpty ||
                        doc['name'].toString().toLowerCase().contains(_search))
                    .toList();
                if (docs.isEmpty) {
                  return const Center(child: Text('No workers found.'));
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    return Dismissible(
                      key: Key(doc.id),
                      background: Container(
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 24),
                        child: const Icon(Icons.delete, color: Colors.red),
                      ),
                      direction: DismissDirection.startToEnd,
                      confirmDismiss: (_) async {
                        await _deleteWorker(doc.id);
                        return false; // Don't auto-dismiss, handle in Firestore
                      },
                      child: Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.deepPurple,
                            child: Icon(Icons.badge, color: Colors.white),
                          ),
                          title: Text(
                            doc['name'],
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: 17,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.deepPurple),
                                tooltip: "Edit",
                                onPressed: () => _addWorkerDialog(
                                  existingId: doc.id,
                                  existingName: doc['name'],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                tooltip: "Delete",
                                onPressed: () => _deleteWorker(doc.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
