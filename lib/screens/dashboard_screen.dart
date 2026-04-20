import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/ball_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/fine_provider.dart';
import '../providers/contribution_provider.dart';
import '../providers/fund_provider.dart';
import 'manage_players_screen.dart';
import 'player_ball_loss_screen.dart';
import 'records_screen.dart';
import 'inventory_screen.dart';
import 'contribution_screen.dart';
import 'leaderboard_screen.dart';
import 'fine_screen.dart';
import 'fund_screen.dart';
import 'report_center_screen.dart';
import 'player_status_screen.dart';
import '../services/cloud_sync_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  bool _isSyncing = false;
  
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeController.forward();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BallProvider>(context, listen: false).init();
      Provider.of<InventoryProvider>(context, listen: false).fetchInventory();
      Provider.of<FineProvider>(context, listen: false).fetchPayments();
      Provider.of<ContributionProvider>(context, listen: false).fetchContributions();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Uint8List? _safeDecode(String? base64String) {
    if (base64String == null || base64String.trim().isEmpty) return null;
    try {
      String cleanString = base64String.trim();
      if (cleanString.contains(',')) {
        cleanString = cleanString.split(',').last;
      }
      return base64Decode(cleanString);
    } catch (e) {
      debugPrint('Decode error: $e');
      return null;
    }
  }

  Future<void> _syncData() async {
    setState(() => _isSyncing = true);
    try {
      final ballProv = Provider.of<BallProvider>(context, listen: false);
      final fineProv = Provider.of<FineProvider>(context, listen: false);
      final contProv = Provider.of<ContributionProvider>(context, listen: false);
      final invProv = Provider.of<InventoryProvider>(context, listen: false);
      final fundProv = Provider.of<FundProvider>(context, listen: false);

      final players = ballProv.players;
      final enriched = players.map((p) {
        final double finePaid = fineProv.getTotalPaidForPlayer(p.id!, 'Overall');
        final double allContribs = contProv.contributions
            .where((c) => c.playerId == p.id!)
            .fold(0.0, (sum, c) => sum + c.taka);
        
        final double totalFineOwed = p.totalLost * 50.0;
        final double totalMoneyGiven = finePaid + allContribs;

        double due = 0; double credit = 0;
        if (totalMoneyGiven >= totalFineOwed) {
          due = 0; credit = totalMoneyGiven - totalFineOwed;
        } else {
          due = totalFineOwed - totalMoneyGiven; credit = 0;
        }

        return {
          'name': p.name,
          'total': p.totalLost,
          'totalFine': totalFineOwed,
          'paid': totalMoneyGiven,
          'due': due,
          'surplus': credit,
        };
      }).toList()..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));

      final leaderboard = ballProv.getMonthlyLeaderboard('Overall');

      final success = await CloudSyncService.syncAllData(
        leaderboard: leaderboard,
        playerStatus: enriched,
        funds: fundProv.funds,
        contributions: contProv.contributions,
        fines: fineProv.payments,
        stock: invProv.inventoryList,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "Cloud Sync Successful!" : "Sync Failed. Try again."),
            backgroundColor: success ? Colors.green : Colors.red,
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final ballProvider = Provider.of<BallProvider>(context);
    final invProvider = Provider.of<InventoryProvider>(context);
    final fineProv = Provider.of<FineProvider>(context);
    final contProv = Provider.of<ContributionProvider>(context);
    
    final isAdmin = authProvider.isAdmin;
    final remainingBalls = invProvider.getCumulativeRemaining('Overall');
    final user = authProvider.currentUser;
    final photoBytes = _safeDecode(user?.photoUrl);

    // Personalized Match for Non-Admins
    Map<String, dynamic>? personalStats;
    if (user != null && ballProvider.players.isNotEmpty) {
      try {
        final players = ballProvider.players;
        int playerIndex = players.indexWhere(
          (p) => p.name.toLowerCase() == user.name.toLowerCase() && p.phone == user.phone
        );
        
        if (playerIndex != -1) {
          final matchedPlayer = players[playerIndex];
          
          final double finePaid = fineProv.getTotalPaidForPlayer(matchedPlayer.id!, 'Overall');
          final double allContribs = contProv.contributions
              .where((c) => c.playerId == matchedPlayer.id!)
              .fold(0.0, (sum, c) => sum + c.taka);
          
          final double totalFineOwed = matchedPlayer.totalLost * 50.0;
          final double totalMoneyGiven = finePaid + allContribs;

          double due = 0; double credit = 0;
          if (totalMoneyGiven >= totalFineOwed) {
            due = 0; credit = totalMoneyGiven - totalFineOwed;
          } else {
            due = totalFineOwed - totalMoneyGiven; credit = 0;
          }

          DateTime? lastDate;
          final combinedHistory = [
            ...fineProv.payments.where((p) => p.playerId == matchedPlayer.id!),
            ...contProv.contributions.where((c) => c.playerId == matchedPlayer.id!)
          ];
          if (combinedHistory.isNotEmpty) {
            combinedHistory.sort((a, b) => (b as dynamic).date.compareTo((a as dynamic).date));
            lastDate = (combinedHistory.first as dynamic).date;
          }

          personalStats = {
            'lost': matchedPlayer.totalLost,
            'due': due,
            'credit': credit,
            'lastPay': lastDate != null ? DateFormat('dd MMM').format(lastDate) : 'No Data',
          };
        }
      } catch (e) {
        debugPrint('Personal Stats Error: $e');
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF020C3B), Color(0xFF051970), Color(0xFF0A2A99)],
              ),
            ),
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: () async {
                  await authProvider.refreshUser();
                  await ballProvider.refresh();
                  await invProvider.fetchInventory(force: true);
                  await fineProv.fetchPayments();
                  await contProv.fetchContributions();
                },
                color: Colors.orange,
                child: FadeTransition(
                  opacity: _fadeController,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _buildHeader(user, photoBytes, authProvider),
                        const SizedBox(height: 25),
                        
                        if (personalStats != null) ...[
                          _buildPersonalStatusCard(personalStats),
                          const SizedBox(height: 25),
                        ],

                        _buildStatsGrid(remainingBalls, ballProvider, invProvider, isAdmin),
                        const SizedBox(height: 35),
                        Row(
                          children: [
                            Container(width: 4, height: 20, decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 10),
                            Text('QUICK ACTIONS', style: GoogleFonts.bebasNeue(fontSize: 20, color: Colors.white, letterSpacing: 1.5)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildActionGrid(context, isAdmin),
                        const SizedBox(height: 40),
                        Center(
                          child: Opacity(
                            opacity: 0.05,
                            child: Image.asset('assets/icon/logo3.png', width: 100, errorBuilder: (c, e, s) => const SizedBox()),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isSyncing)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.orange),
                    const SizedBox(height: 20),
                    Text('SYNCING TO GOOGLE SHEETS...', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1.2)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSyncCard() {
    return InkWell(
      onTap: _syncData,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.cloud_sync_rounded, color: Colors.greenAccent, size: 24),
            ),
            const SizedBox(height: 10),
            Text('CLOUD SYNC', textAlign: TextAlign.center, style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 15, letterSpacing: 0.8)),
            Text('Google Sheets', style: GoogleFonts.poppins(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalStatusCard(Map<String, dynamic> stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white12),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              Text('MY CLUB STATUS', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat('TOTAL LOST', '${stats['lost']} B', Colors.white70),
              _buildMiniStat('FINE DUE', '${stats['due'].toInt()} ৳', stats['due'] > 0 ? Colors.redAccent : Colors.greenAccent),
              _buildMiniStat('CLUB CREDIT', '${stats['credit'].toInt()} ৳', stats['credit'] > 0 ? Colors.greenAccent : Colors.white24),
              _buildMiniStat('LAST PAY', '${stats['lastPay']}', Colors.blueAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String val, Color color) {
    return Column(
      children: [
        Text(val, style: GoogleFonts.bebasNeue(color: color, fontSize: 18)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.bebasNeue(color: Colors.white24, fontSize: 9, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildHeader(user, photoBytes, authProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back,', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
            Text(user?.name ?? 'Player', style: GoogleFonts.bebasNeue(fontSize: 32, color: Colors.white, letterSpacing: 1.2)),
          ],
        ),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)],
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withOpacity(0.1),
                backgroundImage: photoBytes != null ? MemoryImage(photoBytes) : null,
                child: photoBytes == null
                    ? Text(user?.name[0].toUpperCase() ?? '?', style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 24))
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 28),
              onPressed: () => authProvider.logout(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid(int stock, BallProvider ball, InventoryProvider inv, bool isAdmin) {
    int lostTodayRaw = ball.todayRecords.fold(0, (sum, r) => sum + r.lostCount);
    int lostToday = lostTodayRaw < 0 ? 0 : lostTodayRaw;
    
    final currentMonth = DateFormat('MM-yyyy').format(DateTime.now());
    final playersWithTotals = ball.getPlayersWithTotals(monthYear: currentMonth);
    final sortedPlayers = List<Map<String, dynamic>>.from(playersWithTotals)
      ..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
    
    final topLost = sortedPlayers.isNotEmpty ? (sortedPlayers.first['total'] as int) : 0;
    final fine = topLost * 50;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildCompactStatCard('STOCK', '$stock', Colors.greenAccent)),
            const SizedBox(width: 15),
            Expanded(child: _buildCompactStatCard('LOST TODAY', '$lostToday', Colors.redAccent)),
          ],
        ),
        const SizedBox(height: 15),
        InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FineScreen())),
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFE65100), Color(0xFFFF8F00)]),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.monetization_on, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MONTHLY TOP FINE', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1)),
                      Text('Top: ${sortedPlayers.isNotEmpty ? sortedPlayers.first['name'] : "None"}', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Text('$fine', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 32)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStatCard(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(val, style: GoogleFonts.bebasNeue(fontSize: 26, color: color)),
          Text(label, style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, bool isAdmin) {
    List<Widget> cards = [];
    
    if (isAdmin) {
      cards.add(_buildActionCard(context, 'RECORD LOSS', 'Log New Entry', Icons.add_moderator_outlined, const Color(0xFFFF5252), const PlayerBallLossScreen()));
    }
    
    cards.addAll([
      _buildActionCard(context, 'TRACK OVERVIEW', 'History', Icons.auto_graph_rounded, const Color(0xFF42A5F5), const RecordsScreen()),
      _buildActionCard(context, 'LEADERBOARD', 'Ranking', Icons.emoji_events_outlined, const Color(0xFFFFA726), const LeaderboardScreen()),
      _buildActionCard(context, 'STOCK LOG', 'Inventory', Icons.analytics_outlined, const Color(0xFF66BB6A), const InventoryScreen()),
      _buildActionCard(context, 'FINANCIALS', 'Club Income', Icons.account_balance_wallet_outlined, const Color(0xFFAB47BC), const ContributionScreen()),
      _buildActionCard(context, 'CLUB FUND', 'Reserve', Icons.savings_outlined, const Color(0xFF26A69A), const FundScreen()),
      _buildActionCard(context, 'PLAYER STATUS', 'Overview', Icons.assignment_ind_outlined, const Color(0xFF00ACC1), const PlayerStatusScreen()),
      _buildActionCard(context, 'PLAYER FINES', 'Account Status', Icons.warning_amber_rounded, const Color(0xFFEF5350), const FineScreen()),
      _buildActionCard(context, 'REPORT CENTER', 'Monthly PDF', Icons.folder_shared_outlined, const Color(0xFF536DFE), const ReportCenterScreen()),
    ]);

    if (isAdmin) {
      cards.add(_buildSyncCard());
      cards.add(_buildActionCard(context, 'ADMIN PANEL', 'Management', Icons.admin_panel_settings_outlined, const Color(0xFF78909C), const ManagePlayersScreen()));
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      childAspectRatio: 1.25,
      children: cards,
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String subtitle, IconData icon, Color color, Widget screen) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
              borderRadius: BorderRadius.circular(25),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(height: 10),
                    Text(title, textAlign: TextAlign.center, style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 15, letterSpacing: 0.8)),
                    Text(subtitle, style: GoogleFonts.poppins(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
