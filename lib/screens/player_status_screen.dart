import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/ball_provider.dart';
import '../providers/fine_provider.dart';
import '../providers/contribution_provider.dart';
import '../models/fine_payment.dart';
import '../utils/export_service.dart';

class PlayerStatusScreen extends StatefulWidget {
  const PlayerStatusScreen({super.key});

  @override
  State<PlayerStatusScreen> createState() => _PlayerStatusScreenState();
}

class _PlayerStatusScreenState extends State<PlayerStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BallProvider>(context, listen: false).init();
      Provider.of<FineProvider>(context, listen: false).fetchPayments();
      Provider.of<ContributionProvider>(context, listen: false).fetchContributions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ballProv = Provider.of<BallProvider>(context);
    final fineProv = Provider.of<FineProvider>(context);
    final contProv = Provider.of<ContributionProvider>(context);

    if (ballProv.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF051970),
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    final players = ballProv.players;
    final List<Map<String, dynamic>> enriched = players.map((p) {
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
        'id': p.id,
        'name': p.name,
        'photoUrl': p.photoUrl,
        'total': p.totalLost,
        'totalFine': totalFineOwed,
        'paid': totalMoneyGiven,
        'due': due,
        'surplus': credit,
      };
    }).toList()..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text('MASTER PLAYER STATUS', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.orange),
            onPressed: () => ExportService.exportPlayerStatusReport(players: enriched),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderRow(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: enriched.length,
              itemBuilder: (context, index) {
                final p = enriched[index];
                return InkWell(
                  onTap: () => _showPlayerDetails(p),
                  child: _buildPlayerRow(p, index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPlayerDetails(Map<String, dynamic> player) {
    final fineProv = Provider.of<FineProvider>(context, listen: false);
    final contProv = Provider.of<ContributionProvider>(context, listen: false);
    
    final payments = fineProv.payments.where((p) => p.playerId == player['id']).toList();
    final contributions = contProv.contributions.where((c) => c.playerId == player['id']).toList();
    
    final List<dynamic> history = [...payments, ...contributions];
    history.sort((a, b) => b.date.compareTo(a.date));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFF020C3B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: player['photoUrl'] != '' ? MemoryImage(base64Decode(player['photoUrl'])) : null,
                  child: player['photoUrl'] == '' ? Text(player['name'][0], style: const TextStyle(fontSize: 24)) : null,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(player['name'].toString().toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24)),
                      Text('Transaction History', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white38)),
              ],
            ),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSmallStat('DUE', '${player['due'].toInt()} ৳', Colors.redAccent),
                _buildSmallStat('CREDIT', '${player['surplus'].toInt()} ৳', Colors.greenAccent),
                _buildSmallStat('TOTAL PAID', '${player['paid'].toInt()} ৳', Colors.blueAccent),
              ],
            ),
            const SizedBox(height: 25),
            Text('PAYMENT & CONTRIBUTION LOG', style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 16, letterSpacing: 1)),
            const Divider(color: Colors.white10, height: 20),
            Expanded(
              child: history.isEmpty 
                ? Center(child: Text('No transaction history found', style: GoogleFonts.poppins(color: Colors.white24)))
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, i) {
                      final item = history[i];
                      final isFine = item is FinePayment;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isFine ? 'FINE PAYMENT' : 'CONTRIBUTION', style: GoogleFonts.bebasNeue(color: isFine ? Colors.orange : Colors.blueAccent, fontSize: 14)),
                                Text(DateFormat('dd MMM, yyyy').format(item.date), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                              ],
                            ),
                            Text('${(isFine ? item.amountPaid : item.taka).toInt()} ৳', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18)),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallStat(String label, String val, Color color) {
    return Column(
      children: [
        Text(val, style: GoogleFonts.bebasNeue(color: color, fontSize: 18)),
        Text(label, style: GoogleFonts.bebasNeue(color: Colors.white24, fontSize: 10)),
      ],
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF020C3B),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          _tableHeader('RK', 30), // Reduced width
          _tableHeader('PIC', 35), // Reduced width
          Expanded(child: _tableHeader('NAME', 0)),
          _tableHeader('LOST', 40),
          _tableHeader('TOTAL', 50),
          _tableHeader('GIVEN', 50),
          _tableHeader('DUE', 50),
          _tableHeader('CREDIT', 50),
        ],
      ),
    );
  }

  Widget _tableHeader(String text, double width) {
    return SizedBox(
      width: width == 0 ? null : width,
      child: Text(
        text, 
        textAlign: width == 0 ? TextAlign.left : TextAlign.center,
        style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 10, letterSpacing: 1)
      ),
    );
  }

  Widget _buildPlayerRow(Map<String, dynamic> p, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white.withOpacity(0.02) : Colors.transparent,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text('${index + 1}', textAlign: TextAlign.center, style: GoogleFonts.bebasNeue(color: Colors.white24))),
          SizedBox(width: 35, child: Center(
            child: CircleAvatar(
              radius: 12, // Slightly smaller
              backgroundColor: Colors.white10,
              backgroundImage: p['photoUrl'] != null && p['photoUrl'] != '' ? MemoryImage(base64Decode(p['photoUrl'])) : null,
              child: p['photoUrl'] == '' ? Text(p['name'][0], style: const TextStyle(fontSize: 8)) : null,
            ),
          )),
          Expanded(child: Text(p['name'], style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis)),
          SizedBox(width: 40, child: Text('${p['total']}', textAlign: TextAlign.center, style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 14))),
          SizedBox(width: 50, child: Text('${(p['totalFine'] as double).toInt()}', textAlign: TextAlign.right, style: GoogleFonts.bebasNeue(color: Colors.yellowAccent, fontSize: 14))),
          SizedBox(width: 50, child: Text('${(p['paid'] as double).toInt()}', textAlign: TextAlign.right, style: GoogleFonts.bebasNeue(color: Colors.greenAccent, fontSize: 14))),
          SizedBox(width: 50, child: Text('${(p['due'] as double).toInt()}', textAlign: TextAlign.right, style: GoogleFonts.bebasNeue(color: (p['due'] as double) > 0 ? Colors.redAccent : Colors.greenAccent, fontSize: 14))),
          SizedBox(width: 50, child: Text('${(p['surplus'] as double).toInt()}', textAlign: TextAlign.right, style: GoogleFonts.bebasNeue(color: (p['surplus'] as double) > 0 ? Colors.blueAccent : Colors.white10, fontSize: 14))),
        ],
      ),
    );
  }
}
