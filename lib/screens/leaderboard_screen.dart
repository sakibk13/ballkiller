import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/ball_provider.dart';
import '../utils/export_service.dart';
import '../utils/status_dialog.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late List<String> _monthList;
  String _selectedMonthYear = DateFormat('MM-yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _generateMonthList();
  }

  void _generateMonthList() {
    _monthList = ['Overall'];
    DateTime start = DateTime(2026, 4, 1);
    DateTime now = DateTime.now();
    
    DateTime current = DateTime(now.year, now.month, 1);
    while (current.isAfter(start) || current.isAtSameMomentAs(start)) {
      _monthList.add(DateFormat('MM-yyyy').format(current));
      current = DateTime(current.year, current.month - 1, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ballProvider = Provider.of<BallProvider>(context);
    // Data is pre-sorted in provider for speed
    final displayData = ballProvider.getMonthlyLeaderboard(_selectedMonthYear);

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon/logo3.png', width: 35, height: 35, errorBuilder: (c, e, s) => const Icon(Icons.leaderboard, color: Colors.orange)),
            const SizedBox(width: 12),
            Text('TOP PLAYERS', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24, letterSpacing: 2)),
          ],
        ),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.orange),
            onPressed: () async {
              try {
                final ballProvider = Provider.of<BallProvider>(context, listen: false);
                final displayData = ballProvider.getMonthlyLeaderboard(_selectedMonthYear);
                if (displayData.isNotEmpty) {
                  await ExportService.exportLeaderboard(
                    monthYear: _selectedMonthYear,
                    players: displayData,
                  );
                  if (mounted) {
                    StatusDialog.show(context, title: "SUCCESS", message: "Leaderboard PDF Generated!", isSuccess: true);
                  }
                } else {
                  if (mounted) {
                    StatusDialog.show(context, title: "INFO", message: "No data to export for this month", isSuccess: false);
                  }
                }
              } catch (e) {
                if (mounted) {
                  StatusDialog.show(context, title: "ERROR", message: "Failed: $e", isSuccess: false);
                }
              }
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // Month Selector
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF020C3B),
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _monthList.length,
              itemBuilder: (context, index) {
                final m = _monthList[index];
                final isSelected = _selectedMonthYear == m;
                
                String display = m;
                if (m != 'Overall') {
                  try {
                    DateTime date = DateFormat('MM-yyyy').parse(m);
                    display = DateFormat('MMM yy').format(date).toUpperCase();
                  } catch (e) {
                    display = m;
                  }
                }

                return GestureDetector(
                  onTap: () => setState(() => _selectedMonthYear = m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: isSelected ? const LinearGradient(colors: [Colors.orange, Colors.deepOrange]) : null,
                      color: isSelected ? null : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: isSelected ? Colors.orange : Colors.white10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      display,
                      style: GoogleFonts.bebasNeue(
                        color: isSelected ? Colors.white : Colors.white38,
                        fontSize: 15,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ballProvider.refresh(),
              color: Colors.orange,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (displayData.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildTopHighlight(displayData[0]),
                    ),
                  
                  if (ballProvider.isLoading && displayData.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: Colors.orange)),
                    )
                  else if (displayData.isEmpty)
                    SliverFillRemaining(
                      child: Center(child: Text('No data found for this period', style: GoogleFonts.poppins(color: Colors.white24))),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = displayData[index];
                            final isTop = index < 3;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 30,
                                    child: Text(
                                      '${index + 1}',
                                      style: GoogleFonts.bebasNeue(
                                        color: isTop ? Colors.orange : Colors.white24,
                                        fontSize: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: Colors.white.withOpacity(0.1),
                                    backgroundImage: item['photoUrl'] != null && item['photoUrl'].isNotEmpty
                                        ? MemoryImage(base64Decode(item['photoUrl']))
                                        : null,
                                    child: (item['photoUrl'] == null || item['photoUrl'].isEmpty)
                                        ? Text(item['name'][0].toUpperCase(), style: const TextStyle(color: Colors.orange))
                                        : null,
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Text(
                                      item['name'],
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isTop ? Colors.orange.withOpacity(0.1) : Colors.white.withOpacity(0.02),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isTop ? Colors.orange.withOpacity(0.3) : Colors.white10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${item['total']}',
                                          style: GoogleFonts.bebasNeue(
                                            color: isTop ? Colors.orange : Colors.white70,
                                            fontSize: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.auto_delete, color: isTop ? Colors.orange : Colors.white24, size: 14),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          childCount: displayData.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHighlight(Map<String, dynamic> topPlayer) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF020C3B),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF051970),
                  backgroundImage: topPlayer['photoUrl'] != null && topPlayer['photoUrl'].isNotEmpty
                      ? MemoryImage(base64Decode(topPlayer['photoUrl']))
                      : null,
                  child: (topPlayer['photoUrl'] == null || topPlayer['photoUrl'].isEmpty)
                      ? Text(topPlayer['name'][0].toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 50))
                      : null,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)]),
                child: const Icon(Icons.emoji_events, color: Colors.white, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(topPlayer['name'].toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 32, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15), 
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.orange, size: 14),
                const SizedBox(width: 6),
                Text('MONTHLY CHAMPION', style: GoogleFonts.poppins(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
