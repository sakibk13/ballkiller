import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/ball_provider.dart';
import '../providers/auth_provider.dart';
import '../models/ball_record.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<String> _monthList;

  @override
  void initState() {
    super.initState();
    _generateMonthList();
    _tabController = TabController(length: _monthList.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BallProvider>(context, listen: false).fetchAllRecords();
    });
  }

  void _generateMonthList() {
    _monthList = ['Overall'];
    DateTime now = DateTime.now();
    for (int i = 0; i < 11; i++) {
      DateTime date = DateTime(now.year, now.month - i, 1);
      _monthList.add(DateFormat('MM-yyyy').format(date));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ballProvider = Provider.of<BallProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text('TRACK OVERVIEW', style: GoogleFonts.bebasNeue(fontSize: 24, letterSpacing: 1.5, color: Colors.white)),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.orange,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.bebasNeue(fontSize: 14, letterSpacing: 1),
          tabs: _monthList.map((m) {
            String display = m == 'Overall' ? 'OVERALL' : DateFormat('MMMM yyyy').format(DateFormat('MM-yyyy').parse(m)).toUpperCase();
            return Tab(text: display);
          }).toList(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ballProvider.refresh(),
        color: Colors.orange,
        child: TabBarView(
          controller: _tabController,
          children: _monthList.map((m) => _buildMonthTable(m, ballProvider.allRecords)).toList(),
        ),
      ),
    );
  }

  Widget _buildMonthTable(String monthYear, List<BallRecord> allRecords) {
    final isAdmin = Provider.of<AuthProvider>(context, listen: false).isAdmin;
    final filteredRecords = monthYear == 'Overall' 
        ? allRecords 
        : allRecords.where((r) => r.monthYear == monthYear).toList();

    if (filteredRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history_rounded, size: 100, color: Colors.white10),
            const SizedBox(height: 16),
            Text('NO RECORDS FOUND', style: GoogleFonts.bebasNeue(color: Colors.white24, fontSize: 24, letterSpacing: 2)),
          ],
        ),
      );
    }

    // Sort by date descending
    final sorted = List<BallRecord>.from(filteredRecords)..sort((a, b) => b.date.compareTo(a.date));
    
    // Group by Date
    Map<String, List<BallRecord>> groupedByDate = {};
    for (var r in sorted) {
      String dateStr = DateFormat('yyyy-MM-dd').format(r.date);
      groupedByDate.putIfAbsent(dateStr, () => []);
      groupedByDate[dateStr]!.add(r);
    }

    // Sort dates descending
    var dates = groupedByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: dates.length,
      itemBuilder: (context, index) {
        String dateKey = dates[index];
        DateTime date = DateTime.parse(dateKey);
        List<BallRecord> records = groupedByDate[dateKey]!;

        // NET CALCULATION: Group by player and sum lostCount (allowing negatives to offset)
        Map<String, int> summarized = {};
        Map<String, List<BallRecord>> originalRecords = {}; 
        for (var r in records) {
          summarized[r.playerName] = (summarized[r.playerName] ?? 0) + r.lostCount;
          originalRecords.putIfAbsent(r.playerName, () => []);
          originalRecords[r.playerName]!.add(r);
        }

        // FILTER: Only show players who have a Net Loss > 0
        var playerNames = summarized.keys.where((name) => summarized[name]! > 0).toList()..sort();
        
        if (playerNames.isEmpty) return const SizedBox.shrink(); // Hide the date group if no net losses

        return Container(
          margin: const EdgeInsets.only(bottom: 25),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Calendar Date Card
              Container(
                width: 65,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF020C3B), Color(0xFF051970)]),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(DateFormat('MMM').format(date).toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 14)),
                    Text(DateFormat('dd').format(date), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 28, height: 1)),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              // List of records
              Expanded(
                child: Column(
                  children: playerNames.map((name) {
                    final totalLost = summarized[name];
                    final originals = originalRecords[name]!;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name[0].toUpperCase() + name.substring(1).toLowerCase(), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                if (originals.length > 1)
                                  Text('${originals.length} entries summarized', style: const TextStyle(color: Colors.white24, fontSize: 9)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text('$totalLost', style: GoogleFonts.bebasNeue(color: Colors.redAccent, fontSize: 18)),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(width: 10),
                            _buildActionIcon(Icons.edit_outlined, Colors.blueAccent, () => _showEditRecordDialog(context, originals.first)),
                            const SizedBox(width: 5),
                            _buildActionIcon(Icons.delete_outline, Colors.redAccent, () => _showDeleteRecordDialog(context, originals.first)),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  void _showEditRecordDialog(BuildContext context, BallRecord record) {
    final controller = TextEditingController(text: record.lostCount.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF020C3B),
        title: Text('EDIT RECORD', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PLAYER: ${record.playerName}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'LOST BALLS',
                labelStyle: TextStyle(color: Colors.white38),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              int? newVal = int.tryParse(controller.text);
              if (newVal != null) {
                final updatedRecord = BallRecord(
                  id: record.id,
                  playerId: record.playerId,
                  playerName: record.playerName,
                  lostCount: newVal,
                  date: record.date,
                  recordedBy: record.recordedBy,
                  monthYear: record.monthYear,
                  note: record.note,
                );
                Provider.of<BallProvider>(context, listen: false).updateRecord(updatedRecord, record.lostCount);
                Navigator.pop(ctx);
              }
            },
            child: const Text('UPDATE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteRecordDialog(BuildContext context, BallRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF020C3B),
        title: Text('DELETE RECORD', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
        content: Text('Are you sure you want to delete this record for ${record.playerName}?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              Provider.of<BallProvider>(context, listen: false).deleteRecord(record.id!, record.playerId, record.lostCount);
              Navigator.pop(ctx);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
