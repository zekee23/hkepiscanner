import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QRScannerScreen extends StatefulWidget {
  final String userId;

  const QRScannerScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  bool _isFlashOn = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggleFlash() {
    _isFlashOn = !_isFlashOn;
    _controller.toggleTorch();
    setState(() {});
  }

  Future<void> handleScanResult(String scannedName) async {
    final workersRef = FirebaseFirestore.instance.collection('workers');
    final workerSnapshot = await workersRef.get();

    // Case-insensitive matching
    QueryDocumentSnapshot<Map<String, dynamic>>? matchedDoc;
    for (var doc in workerSnapshot.docs) {
      final name = doc.data()['name']?.toString().toLowerCase();
      if (name == scannedName.toLowerCase()) {
        matchedDoc = doc;
        break;
      }
    }

    if (matchedDoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Worker "$scannedName" not found!')),
      );
      return;
    }

    final workerId = matchedDoc.id;
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    final attDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('attendance')
        .doc(workerId);

    final attDoc = await attDocRef.get();

    List<String> dates = [];
    Map<String, dynamic> scanTimes = {};
    Map<String, String> statuses = {};

    if (attDoc.exists) {
      final data = attDoc.data()!;
      if (data.containsKey('dates')) {
        dates = List<String>.from(data['dates']);
      }
      if (data.containsKey('scan_times')) {
        scanTimes = Map<String, dynamic>.from(data['scan_times']);
      }
      if (data.containsKey('status_by_date')) {
        statuses = Map<String, String>.from(data['status_by_date']);
      }
    }

    // Add today if not in dates
    if (!dates.contains(today)) {
      dates.add(today);
      dates.sort(); // ascending
      if (dates.length > 7) {
        dates = dates.sublist(dates.length - 7); // keep latest 7
      }
    }

    // Update maps
    scanTimes[today] = formattedTime;
    statuses[today] = 'present';

    if (attDoc.exists) {
      await attDocRef.update({
        'dates': dates,
        'scan_times.$today': formattedTime,
        'status_by_date.$today': 'present',
      });
    } else {
      await attDocRef.set({
        'dates': dates,
        'scan_times': {today: formattedTime},
        'status_by_date': {today: 'present'},
        'worker_id': workerId,
        'name': matchedDoc.data()['name'],
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Attendance marked for ${matchedDoc.data()['name']}!')),
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final String? code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);

    // Small delay to debounce and prevent rapid multiple triggers
    await Future.delayed(const Duration(milliseconds: 300));

    _controller.stop();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AssignmentDialog(
        qrCode: code,
        userId: widget.userId, // pass it here
      ),
    );

    if (result != null && mounted) {
      await handleScanResult(result['qrCode']);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Attendance recorded for: ${result['qrCode']}'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    await Future.delayed(const Duration(milliseconds: 1100));

    if (mounted) {
      setState(() => _isProcessing = false);
      _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Scan QR Code'),
        iconTheme: const IconThemeData(color: Colors.white),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: _toggleFlash,
          )
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            fit: BoxFit.cover,
            onDetect: _onDetect,
          ),
          Container(color: Colors.black.withOpacity(0.55)),
          _buildScannerOverlay(),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.85),
                  foregroundColor: Colors.indigo,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            children: [
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color.fromARGB(255, 98, 98, 98), width: 3),
                ),
              ),
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Positioned(
                    top: _animation.value * 240,
                    left: 0,
                    right: 0,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                },
              ),
              const Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Align QR code here',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AssignmentDialog extends StatefulWidget {
  final String qrCode;
  final String userId;

  const AssignmentDialog({
    super.key,
    required this.qrCode,
    required this.userId,
  });

  @override
  State<AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<AssignmentDialog> {
  String? _selectedAssignment;
  final List<String> _assignments = ['Site A', 'Site B', 'Site C'];

  Future<void> handleScanResult(String scannedName) async {
    final workersRef = FirebaseFirestore.instance.collection('workers');
    final workerSnapshot =
        await workersRef.where('name', isEqualTo: scannedName).limit(1).get();

    if (workerSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Worker "$scannedName" not found!')),
      );
      return;
    }

    final workerDoc = workerSnapshot.docs.first;
    final workerId = workerDoc.id;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final userId = widget.userId;

    final attDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId) // <-- use the actual userId
        .collection('attendance')
        .doc(workerId);

    final attDoc = await attDocRef.get();

    List<dynamic> dates = [];
    if (attDoc.exists && attDoc.data()!.containsKey('dates')) {
      dates = List<String>.from(attDoc['dates']);
    }

    if (!dates.contains(today)) {
      dates.add(today);
      dates.sort();
      if (dates.length > 7) {
        dates = dates.sublist(dates.length - 7);
      }

      await attDocRef.set({
        'dates': dates,
        'worker_id': workerId,
        'name': scannedName,
      }, SetOptions(merge: true));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Attendance marked for $scannedName!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(Icons.assignment_ind, color: Colors.purple[700]),
          const SizedBox(width: 8),
          const Text(
            'Assign Worker',
            style: TextStyle(color: Colors.purple),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scanned QR Code:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.qr_code, color: Colors.purple[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.qrCode,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[700],
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Select Assignment',
              border: OutlineInputBorder(),
            ),
            value: _selectedAssignment,
            items: _assignments
                .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                .toList(),
            onChanged: (val) => setState(() => _selectedAssignment = val),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.purple[700]),
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.check, color: Colors.white),
          label: const Text(
            'Done',
            style: TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple[700],
          ),
          onPressed: _selectedAssignment == null
              ? null
              : () {
                  final now = DateTime.now();
                  final formattedDate =
                      DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
                  Navigator.of(context).pop({
                    'qrCode': widget.qrCode,
                    'assignment': _selectedAssignment,
                    'date': formattedDate,
                  });
                },
        ),
      ],
    );
  }
}
