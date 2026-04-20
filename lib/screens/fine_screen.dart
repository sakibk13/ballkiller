import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/ball_provider.dart';
import '../providers/fine_provider.dart';
import '../providers/contribution_provider.dart';
import '../providers/auth_provider.dart';
import '../models/fine_payment.dart';
import '../models/contribution.dart';
import '../utils/export_service.dart';
import '../utils/status_dialog.dart';

class FineScreen extends StatefulWidget {
  const FineScreen({super.key});

  @override
  State<FineScreen> createState() => _FineScreenState();
}

class _FineScreenState extends State<FineScreen> {
  String _selectedMonthYear = DateFormat('MM-yyyy').format(DateTime.now());
  late List<String> _monthList;

  @override
  void initState() {
    super.initState();
    _generateMonthList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BallProvider>(context, listen: false).init();
      Provider.of<FineProvider>(context, listen: false).fetchPayments();
      Provider.of<ContributionProvider>(context, listen: false).fetchContributions();
    });
  }

  void _generateMonthList() {
    _monthList = ['Overall'];
    DateTime now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      DateTime date = DateTime(now.year, now.month - i, 1);
      _monthList.add(DateFormat('MM-yyyy').format(date));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ballProvider = Provider.of<BallProvider>(context);
    final fineProvider = Provider.of<FineProvider>(context);
    final contributionProvider = Provider.of<ContributionProvider>(context);
    
    final playersWithTotals = ballProvider.getPlayersWithTotals(monthYear: _selectedMonthYear);
    
    final enrichedPlayers = playersWithTotals.map((p) {
      final String playerId = p['id'];
      final int totalLost = p['total'] as int;
      final double totalFineOwed = totalLost * 50.0;
      
      final double directFinePayments = fineProvider.getTotalPaidForPlayer(playerId, _selectedMonthYear);
      final double allContributions = contributionProvider.contributions
          .where((c) => c.playerId == playerId && (_selectedMonthYear == 'Overall' || c.monthYear == _selectedMonthYear))
          .fold(0.0, (sum, c) => sum + c.taka);

      final double totalMoneyGiven = directFinePayments + allContributions;
      
      double due = 0;
      double credit = 0;
      
      if (totalMoneyGiven >= totalFineOwed) {
        due = 0;
        credit = totalMoneyGiven - totalFineOwed;
      } else {
        due = totalFineOwed - totalMoneyGiven;
        credit = 0;
      }

      return {
        ...p,
        'totalFine': totalFineOwed,
        'paid': totalMoneyGiven, 
        'due': due,
        'surplus': credit,
      };
    }).toList();

    final sortedPlayers = List<Map<String, dynamic>>.from(enrichedPlayers)
      ..sort((a, b) => (b['total'] as num).compareTo(a['total'] as num));

    final topPlayer = sortedPlayers.isNotEmpty ? sortedPlayers.first : null;
    final int topLost = topPlayer != null ? (topPlayer['total'] as int) : 0;
    final double topFine = topPlayer != null ? topPlayer['totalFine'] : 0.0;
    final double topGiven = topPlayer != null ? topPlayer['paid'] : 0.0;
    final double topDue = topPlayer != null ? topPlayer['due'] : 0.0;
    final double topCredit = topPlayer != null ? topPlayer['surplus'] : 0.0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF051970),
        appBar: AppBar(
          title: Text('PLAYER FINES', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
          backgroundColor: const Color(0xFF020C3B),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.orange),
              onPressed: () async {
                try {
                  await ExportService.exportFineReport(
                    monthYear: _selectedMonthYear,
                    sortedPlayers: sortedPlayers,
                  );
                  if (mounted) {
                    StatusDialog.show(context, title: "SUCCESS", message: "Fine Report Generated!", isSuccess: true);
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
          bottom: TabBar(
            indicatorColor: Colors.orange,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.white38,
            labelStyle: GoogleFonts.bebasNeue(letterSpacing: 1.2),
            tabs: const [
              Tab(text: 'NOTICES', icon: Icon(Icons.warning_amber_rounded)),
              Tab(text: 'GIVEN HISTORY', icon: Icon(Icons.history_edu_outlined)),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildMonthPicker(),
            Expanded(
              child: TabBarView(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        if (topPlayer != null && (topLost > 0 || topCredit > 0)) ...[
                          _buildFineCard(topPlayer, topLost, topFine, topGiven, topDue, topCredit),
                          const SizedBox(height: 30),
                          _buildSectionHeader('RANKING ${_selectedMonthYear == 'Overall' ? 'OVERALL' : 'THIS MONTH'}'),
                          const SizedBox(height: 15),
                          _buildRankingList(sortedPlayers),
                        ] else ...[
                          const SizedBox(height: 100),
                          const Icon(Icons.verified_user_outlined, color: Colors.greenAccent, size: 80),
                          const SizedBox(height: 20),
                          Text('EVERYTHING IS CLEAR', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 24)),
                        ],
                      ],
                    ),
                  ),
                  _buildGivenHistoryTab(fineProvider, contributionProvider),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: Provider.of<AuthProvider>(context, listen: false).isAdmin 
          ? FloatingActionButton(
              onPressed: () => _showAddFineGivenDialog(context, enrichedPlayers),
              backgroundColor: Colors.orange,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      ),
    );
  }

  Widget _buildMonthPicker() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: const Color(0xFF020C3B),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: _monthList.length,
        itemBuilder: (context, index) {
          final m = _monthList[index];
          final isSelected = _selectedMonthYear == m;
          String display = m == 'Overall' ? 'OVERALL' : DateFormat('MMM yy').format(DateFormat('MM-yyyy').parse(m)).toUpperCase();
          return GestureDetector(
            onTap: () => setState(() => _selectedMonthYear = m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                gradient: isSelected ? const LinearGradient(colors: [Colors.orange, Colors.deepOrange]) : null,
                color: isSelected ? null : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? Colors.orange : Colors.white10),
              ),
              alignment: Alignment.center,
              child: Text(display, style: GoogleFonts.bebasNeue(color: isSelected ? Colors.white : Colors.white38, fontSize: 16, letterSpacing: 1)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFineCard(Map<String, dynamic> player, int lost, double fine, double given, double due, double credit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB71C1C), Color(0xFFD32F2F), Color(0xFFC62828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 25, spreadRadius: 5)
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.account_balance_outlined, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CLUB ACCOUNT STATUS', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 16, letterSpacing: 1.5)),
                    Text(player['name'][0].toUpperCase() + player['name'].substring(1).toLowerCase(), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24, letterSpacing: 1.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white30, width: 2)),
            child: CircleAvatar(
              radius: 45,
              backgroundColor: Colors.white24,
              backgroundImage: player['photoUrl'] != null && player['photoUrl'].isNotEmpty 
                  ? MemoryImage(base64Decode(player['photoUrl'])) 
                  : null,
              child: player['photoUrl'] == null || player['photoUrl'].isEmpty 
                  ? Text(player['name'][0], style: const TextStyle(color: Colors.white, fontSize: 35)) 
                  : null,
            ),
          ),
          const SizedBox(height: 25),
          
          Row(
            children: [
              Expanded(child: _buildSquareDetail('BALLS LOST', '$lost', Colors.white.withOpacity(0.15))),
              const SizedBox(width: 10),
              Expanded(child: _buildSquareDetail('TOTAL FINE', '${fine.toInt()}', Colors.yellowAccent.withOpacity(0.2), textCol: Colors.yellowAccent)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildSquareDetail('TOTAL GIVEN', '${given.toInt()}', Colors.blueAccent.withOpacity(0.2), textCol: Colors.blueAccent)),
              const SizedBox(width: 10),
              Expanded(child: _buildSquareDetail('CLUB CREDIT', '${credit.toInt()}', Colors.greenAccent.withOpacity(0.2), textCol: Colors.greenAccent)),
            ],
          ),
          const SizedBox(height: 10),
          _buildSquareDetail('DUE BALANCE', '${due.toInt()}', due > 0 ? Colors.black.withOpacity(0.3) : Colors.greenAccent.withOpacity(0.2), textCol: due > 0 ? Colors.orangeAccent : Colors.greenAccent, fullWidth: true),

          const SizedBox(height: 20),
          Text(
            '* Club Credit represents your available balance that automatically covers any fines.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white60, fontSize: 10, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildSquareDetail(String label, String val, Color bg, {Color textCol = Colors.white, bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 10, letterSpacing: 1)),
          Text(val, style: GoogleFonts.bebasNeue(color: textCol, fontSize: 20)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 5, height: 22, decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 15),
        Text(title, style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 22, letterSpacing: 1.5)),
      ],
    );
  }

  Widget _buildRankingList(List<Map<String, dynamic>> players) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: players.length,
      itemBuilder: (context, i) {
        final p = players[i];
        final total = p['total'] as int;
        final given = p['paid'] as double;
        final due = p['due'] as double;
        final credit = p['surplus'] as double;

        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: i == 0 ? Colors.redAccent.withOpacity(0.4) : Colors.white10),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text('${i + 1}', style: GoogleFonts.bebasNeue(color: i == 0 ? Colors.redAccent : Colors.white24, fontSize: 20)),
                  const SizedBox(width: 15),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white10,
                    backgroundImage: p['photoUrl'] != null && p['photoUrl'] != '' 
                        ? MemoryImage(base64Decode(p['photoUrl'])) 
                        : null,
                    child: p['photoUrl'] == null || p['photoUrl'] == '' ? Text(p['name'][0], style: const TextStyle(color: Colors.orange)) : null,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(p['name'][0].toUpperCase() + p['name'].substring(1).toLowerCase(), style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$total BALLS', style: GoogleFonts.bebasNeue(color: i == 0 ? Colors.redAccent : Colors.white70, fontSize: 15)),
                      if (credit > 0)
                        Text('CREDIT: ${credit.toInt()}', style: GoogleFonts.bebasNeue(color: Colors.greenAccent, fontSize: 13)),
                    ],
                  ),
                ],
              ),
              if (total > 0 || credit > 0) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniStatus('GIVEN', '${given.toInt()}', Colors.blueAccent),
                    _buildMiniStatus('DUE', '${due.toInt()}', due > 0 ? Colors.orangeAccent : Colors.greenAccent),
                    _buildMiniStatus('CREDIT', '${credit.toInt()}', credit > 0 ? Colors.greenAccent : Colors.white10),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStatus(String label, String val, Color color) {
    return Row(
      children: [
        Text('$label: ', style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 12)),
        Text(val, style: GoogleFonts.bebasNeue(color: color, fontSize: 14)),
      ],
    );
  }

  Widget _buildGivenHistoryTab(FineProvider fineProvider, ContributionProvider contributionProvider) {
    final directPayments = fineProvider.getPaymentsForMonth(_selectedMonthYear);
    final contribFines = contributionProvider.contributions
        .where((c) => (_selectedMonthYear == 'Overall' || c.monthYear == _selectedMonthYear) && c.isFinePayment)
        .toList();

    final List<dynamic> combinedHistory = [...directPayments, ...contribFines];
    combinedHistory.sort((a, b) => b.date.compareTo(a.date));

    if (combinedHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history_edu_outlined, color: Colors.white10, size: 80),
            const SizedBox(height: 20),
            Text('NO GIVEN HISTORY', style: GoogleFonts.bebasNeue(color: Colors.white24, fontSize: 24)),
          ],
        ),
      );
    }

    Map<String, List<dynamic>> grouped = {};
    for (var p in combinedHistory) {
      String dateStr = DateFormat('yyyy-MM-dd').format(p.date);
      grouped.putIfAbsent(dateStr, () => []);
      grouped[dateStr]!.add(p);
    }
    var dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: dates.length,
      itemBuilder: (context, index) {
        String dateKey = dates[index];
        DateTime date = DateTime.parse(dateKey);
        List<dynamic> items = grouped[dateKey]!;

        return Container(
          margin: const EdgeInsets.only(bottom: 25),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Expanded(
                child: Column(
                  children: items.map((p) {
                    bool isDirect = p is FinePayment;
                    String name = isDirect ? p.playerName : p.name;
                    String note = isDirect ? (p.note ?? "Fine Payment") : "(Via Contrib) ${p.ballTape}";
                    double amount = isDirect ? p.amountPaid : p.taka;

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
                                Text(note, style: const TextStyle(color: Colors.white38, fontSize: 9)),
                              ],
                            ),
                          ),
                          Text('${amount.toInt()}', style: GoogleFonts.bebasNeue(color: Colors.greenAccent, fontSize: 18)),
                          if (Provider.of<AuthProvider>(context, listen: false).isAdmin) ...[
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () {
                                if (isDirect) {
                                  _confirmDeleteGivenFine(context, fineProvider, p);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete this via Financials tab')));
                                }
                              },
                              child: Icon(Icons.delete_outline, color: isDirect ? Colors.redAccent : Colors.white10, size: 18),
                            ),
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

  void _confirmDeleteGivenFine(BuildContext context, FineProvider provider, FinePayment payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF020C3B),
        title: Text('DELETE RECORD', style: GoogleFonts.bebasNeue(color: Colors.white)),
        content: Text('Remove this record of ${payment.amountPaid.toInt()}?', style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: GoogleFonts.poppins())),
          TextButton(
            onPressed: () {
              provider.deletePayment(payment.id!);
              Navigator.pop(context);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showAddFineGivenDialog(BuildContext context, List<Map<String, dynamic>> players) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only admins can add collection records')));
      return;
    }

    final formKey = GlobalKey<FormState>();
    String? selectedPlayerId;
    String? selectedPlayerName;
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool syncToFinancials = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF020C3B),
          title: Text('ADD FINE GIVEN', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') return const Iterable<Map<String, dynamic>>.empty();
                      return players.where((p) => p['name'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    displayStringForOption: (p) => p['name'].toString().toUpperCase(),
                    onSelected: (p) {
                      selectedPlayerId = p['id'];
                      selectedPlayerName = p['name'];
                    },
                    fieldViewBuilder: (ctx, ctrl, focus, onSub) => TextFormField(
                      controller: ctrl,
                      focusNode: focus,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('SEARCH PLAYER'),
                      validator: (v) => selectedPlayerId == null ? 'Select a player' : null,
                    ),
                    optionsViewBuilder: (ctx, onSelected, options) => Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: const Color(0xFF020C3B),
                        elevation: 4.0,
                        child: Container(
                          width: 250,
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (ctx, i) {
                              final p = options.elementAt(i);
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 15,
                                  backgroundColor: Colors.white10,
                                  backgroundImage: p['photoUrl'] != null && p['photoUrl'] != '' ? MemoryImage(base64Decode(p['photoUrl'])) : null,
                                  child: p['photoUrl'] == null || p['photoUrl'] == '' ? Text(p['name'][0], style: const TextStyle(fontSize: 10)) : null,
                                ),
                                title: Text(p['name'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13)),
                                subtitle: Text('Total Lost: ${p['total']} balls', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                onTap: () => onSelected(p),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: amountController,
                    decoration: _inputDecoration('GIVEN AMOUNT'),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    validator: (val) => val == null || val.isEmpty ? 'Enter amount' : null,
                  ),
                  const SizedBox(height: 15),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setDialogState(() => selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('DATE: ${DateFormat('MMM dd, yyyy').format(selectedDate)}', style: const TextStyle(color: Colors.white70)),
                          const Icon(Icons.calendar_today, color: Colors.orange, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("ADD TO FINANCIALS?", style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11)),
                        Switch(
                          value: syncToFinancials, 
                          onChanged: (v) => setDialogState(() => syncToFinancials = v),
                          activeColor: Colors.orange,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: noteController,
                    decoration: _inputDecoration('OPTIONAL NOTE'),
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: GoogleFonts.poppins())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                if (formKey.currentState!.validate() && selectedPlayerId != null) {
                  final amount = double.parse(amountController.text);
                  
                  bool success = false;
                  
                  if (syncToFinancials) {
                    final contrib = Contribution(
                      playerId: selectedPlayerId,
                      name: selectedPlayerName!,
                      taka: amount,
                      date: selectedDate,
                      monthYear: DateFormat('MM-yyyy').format(selectedDate),
                      ballTape: "Fine Collection: ${noteController.text}",
                      isFinePayment: true,
                    );
                    success = await Provider.of<ContributionProvider>(context, listen: false).addContribution(contrib);
                  } else {
                    final payment = FinePayment(
                      playerId: selectedPlayerId!,
                      playerName: selectedPlayerName!,
                      amountPaid: amount,
                      date: selectedDate,
                      note: noteController.text,
                      monthYear: DateFormat('MM-yyyy').format(selectedDate),
                    );
                    success = await Provider.of<FineProvider>(context, listen: false).addPayment(payment);
                  }

                  if (success) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record added successfully')));
                  }
                }
              },
              child: Text('SAVE RECORD', style: GoogleFonts.bebasNeue(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.orange)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
    );
  }
}
