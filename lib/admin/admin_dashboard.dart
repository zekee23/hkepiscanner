import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboardStatistics extends StatefulWidget {
  const AdminDashboardStatistics({Key? key}) : super(key: key);

  @override
  State<AdminDashboardStatistics> createState() =>
      _AdminDashboardStatisticsState();
}

class _AdminDashboardStatisticsState extends State<AdminDashboardStatistics> {
  late final List<DateTime> _last7Days;
  Map<String, int> _attendeesPerDay = {};
  Map<String, int> _absenteesPerDay = {};
  Map<String, List<String>> _namesPerDayPresent = {};
  Map<String, List<String>> _namesPerDayAbsent = {};

  int _totalWorkers = 0;
  bool _loading = true;

  late String _selectedDayStr;
  String _filterStatus = 'present';

  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _last7Days =
        List.generate(7, (i) => DateTime.now().subtract(Duration(days: 6 - i)));
    _selectedDayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    _searchController.addListener(() {
      setState(() {
        _searchTerm = _searchController.text.toLowerCase();
      });
    });

    _initRealtimeListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initRealtimeListener() async {
    setState(() => _loading = true);

    final workerSnapshot =
        await FirebaseFirestore.instance.collection('workers').get();
    final totalWorkers = workerSnapshot.docs.length;

    final Map<String, int> attendees = {
      for (var day in _last7Days) DateFormat('yyyy-MM-dd').format(day): 0,
    };
    final Map<String, int> absentees = {
      for (var day in _last7Days) DateFormat('yyyy-MM-dd').format(day): 0,
    };
    final Map<String, List<String>> namesPresent = {
      for (var day in _last7Days) DateFormat('yyyy-MM-dd').format(day): [],
    };
    final Map<String, List<String>> namesAbsent = {
      for (var day in _last7Days) DateFormat('yyyy-MM-dd').format(day): [],
    };

    final userSnapshot =
        await FirebaseFirestore.instance.collection('users').get();

    await Future.wait(userSnapshot.docs.map((userDoc) async {
      final attendanceSnapshot =
          await userDoc.reference.collection('attendance').get();

      for (var attDoc in attendanceSnapshot.docs) {
        final data = attDoc.data();
        final userName = data['name'] ?? 'Unnamed';
        final statusMap =
            Map<String, dynamic>.from(data['status_by_date'] ?? {});

        for (var day in _last7Days) {
          final dayStr = DateFormat('yyyy-MM-dd').format(day);
          final status = statusMap[dayStr];
          if (status == 'present') {
            attendees[dayStr] = (attendees[dayStr] ?? 0) + 1;
            namesPresent[dayStr]?.add(userName);
          } else if (status == 'absent') {
            absentees[dayStr] = (absentees[dayStr] ?? 0) + 1;
            namesAbsent[dayStr]?.add(userName);
          }
        }
      }
    }));

    if (mounted) {
      setState(() {
        _totalWorkers = totalWorkers;
        _attendeesPerDay = attendees;
        _absenteesPerDay = absentees;
        _namesPerDayPresent = namesPresent;
        _namesPerDayAbsent = namesAbsent;
        _loading = false;
      });
    }
  }

  CircleAvatar _buildInitialsAvatar(String name) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((e) => e[0]).take(2).join()
        : '?';

    return CircleAvatar(
      radius: 20,
      child: Text(
        initials.toUpperCase(),
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      backgroundColor: Colors.deepPurple.shade400,
    );
  }

  Widget _legendDot(Color color) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _buildStatusTile(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final namesToShow = List<String>.from(
      _filterStatus == 'present'
          ? _namesPerDayPresent[_selectedDayStr] ?? []
          : _namesPerDayAbsent[_selectedDayStr] ?? [],
    );

    final filteredNames = namesToShow
        .where((name) => name.toLowerCase().contains(_searchTerm))
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return RefreshIndicator(
      onRefresh: _initRealtimeListener,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            /// Summary Cards (Present / Absent)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatusTile('Present',
                    _attendeesPerDay[_selectedDayStr] ?? 0, Colors.green),
                _buildStatusTile('Absent',
                    _absenteesPerDay[_selectedDayStr] ?? 0, Colors.red),
              ],
            ),
            const SizedBox(height: 16),

            /// Chart Card
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Attendance - Last 7 Days',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 220,
                      child: BarChart(
                        BarChartData(
                          borderData: FlBorderData(show: false),
                          gridData:
                              FlGridData(show: true, horizontalInterval: 1),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                reservedSize: 32,
                                getTitlesWidget: (value, _) => Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Text(
                                    value.toInt().toString(),
                                    style: GoogleFonts.poppins(fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, _) {
                                  final idx = value.toInt();
                                  if (idx < 0 || idx >= _last7Days.length) {
                                    return const SizedBox();
                                  }
                                  final day = _last7Days[idx];
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      DateFormat('E').format(day),
                                      style: GoogleFonts.poppins(fontSize: 12),
                                    ),
                                  );
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          barGroups: List.generate(_last7Days.length, (i) {
                            final dayStr =
                                DateFormat('yyyy-MM-dd').format(_last7Days[i]);
                            final presentCount = _attendeesPerDay[dayStr] ?? 0;
                            final absentCount = _absenteesPerDay[dayStr] ?? 0;

                            return BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: presentCount.toDouble() +
                                      absentCount.toDouble(),
                                  rodStackItems: [
                                    BarChartRodStackItem(
                                        0,
                                        presentCount.toDouble(),
                                        Colors.deepPurple),
                                    BarChartRodStackItem(
                                        presentCount.toDouble(),
                                        presentCount.toDouble() +
                                            absentCount.toDouble(),
                                        Colors.red.shade300),
                                  ],
                                  borderRadius: BorderRadius.circular(6),
                                  width: 24,
                                ),
                              ],
                            );
                          }),
                          groupsSpace: 18,
                          maxY: (_totalWorkers.toDouble() + 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _legendDot(Colors.deepPurple),
                        const SizedBox(width: 6),
                        Text('Present',
                            style: GoogleFonts.poppins(fontSize: 13)),
                        const SizedBox(width: 18),
                        _legendDot(Colors.red.shade300),
                        const SizedBox(width: 6),
                        Text('Absent',
                            style: GoogleFonts.poppins(fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total Workers: $_totalWorkers',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<String>(
                  value: _selectedDayStr,
                  items: _last7Days
                      .map((day) => DropdownMenuItem<String>(
                            value: DateFormat('yyyy-MM-dd').format(day),
                            child: Text(DateFormat('MMM dd').format(day)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedDayStr = val;
                        _searchController.clear();
                      });
                    }
                  },
                ),
                DropdownButton<String>(
                  value: _filterStatus,
                  items: ['present', 'absent']
                      .map((status) => DropdownMenuItem<String>(
                            value: status,
                            child: Text(
                                status[0].toUpperCase() + status.substring(1)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _filterStatus = val;
                        _searchController.clear();
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            /// Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search workers...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        '${_filterStatus == 'present' ? 'Present Workers' : 'Absent Workers'} (${filteredNames.length})',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (filteredNames.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No ${_filterStatus == 'present' ? 'present' : 'absent'} workers.',
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: Colors.grey[700]),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredNames.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          thickness: 0.5,
                          color: Colors.grey.shade300,
                          indent: 72,
                        ),
                        itemBuilder: (context, index) {
                          final name = filteredNames[index];
                          return InkWell(
                            onTap: () {
                              // Optional: action on tap, e.g., show details
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  _buildInitialsAvatar(name),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Tooltip(
                                      message: name,
                                      child: Text(
                                        name,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
