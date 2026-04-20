import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/ball_provider.dart';
import '../providers/fund_provider.dart';
import '../providers/auth_provider.dart';
import '../models/fund.dart';
import '../utils/export_service.dart';

class FundScreen extends StatefulWidget {
  const FundScreen({super.key});

  @override
  State<FundScreen> createState() => _FundScreenState();
}

class _FundScreenState extends State<FundScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FundProvider>(context, listen: false).fetchFunds();
    });
  }

  @override
  Widget build(BuildContext context) {
    final fundProvider = Provider.of<FundProvider>(context);
    final ballProvider = Provider.of<BallProvider>(context);
    final isAdmin = Provider.of<AuthProvider>(context, listen: false).isAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text('Club Fund', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.orange),
            onPressed: () {
              ExportService.exportFundReport(
                funds: fundProvider.funds,
                grandTotal: fundProvider.grandTotal,
                players: ballProvider.players,
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          _buildStylishBalanceCard(fundProvider.grandTotal),
          Expanded(
            child: fundProvider.isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : _buildCategorizedFundList(fundProvider, ballProvider, isAdmin),
          ),
        ],
      ),
      floatingActionButton: isAdmin ? FloatingActionButton(
        onPressed: () => _showAddFundDialog(context),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
    );
  }

  Widget _buildStylishBalanceCard(double total) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF020C3B),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10)),
          BoxShadow(color: Colors.greenAccent.withOpacity(0.05), blurRadius: 40, spreadRadius: -10),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TREASURY BALANCE', style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 14, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${total.toInt()}', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 48, letterSpacing: 1)),
                      const SizedBox(width: 8),
                      Text('BDT', style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 18)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.greenAccent.withOpacity(0.2), Colors.greenAccent.withOpacity(0.05)]),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
                ),
                child: const Icon(Icons.account_balance_rounded, color: Colors.greenAccent, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(15)),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white24, size: 14),
                const SizedBox(width: 8),
                Text('Real-time club savings from all sources', style: GoogleFonts.poppins(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorizedFundList(FundProvider provider, BallProvider ballProv, bool isAdmin) {
    if (provider.funds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, color: Colors.white10, size: 80),
            const SizedBox(height: 20),
            Text('No History Found', style: GoogleFonts.bebasNeue(color: Colors.white24, fontSize: 24)),
          ],
        ),
      );
    }

    Map<String, List<Fund>> monthGroups = {};
    for (var f in provider.funds) {
      String monthKey = DateFormat('MMMM yyyy').format(f.date);
      monthGroups.putIfAbsent(monthKey, () => []);
      monthGroups[monthKey]!.add(f);
    }

    // FILTER: Only show months from April 2026 onwards
    DateTime minDate = DateTime(2026, 4, 1);
    var sortedMonths = monthGroups.keys.where((m) {
      return DateFormat('MMMM yyyy').parse(m).isAfter(minDate.subtract(const Duration(days: 1)));
    }).toList()..sort((a, b) {
      DateTime da = DateFormat('MMMM yyyy').parse(a);
      DateTime db = DateFormat('MMMM yyyy').parse(b);
      return db.compareTo(da);
    });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: sortedMonths.length,
      itemBuilder: (context, mIndex) {
        String monthName = sortedMonths[mIndex];
        List<Fund> monthFunds = monthGroups[monthName]!;
        double monthNet = monthFunds.fold(0, (sum, f) => f.type == 'EXPENSE' ? sum - f.amount : sum + f.amount);

        Map<String, List<Fund>> dailyGroups = {};
        for (var f in monthFunds) {
          String dateKey = DateFormat('yyyy-MM-dd').format(f.date);
          dailyGroups.putIfAbsent(dateKey, () => []);
          dailyGroups[dateKey]!.add(f);
        }
        var sortedDates = dailyGroups.keys.toList()..sort((a, b) => b.compareTo(a));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                children: [
                  Container(width: 4, height: 22, decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(monthName, style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 20, letterSpacing: 1)),
                  ),
                  Text('Net: ${monthNet.toInt()}', style: GoogleFonts.bebasNeue(color: monthNet >= 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 14)),
                ],
              ),
            ),
            
            ...sortedDates.map((dateKey) {
              DateTime date = DateTime.parse(dateKey);
              List<Fund> items = dailyGroups[dateKey]!;
              double dailyNet = items.fold(0, (sum, f) => f.type == 'EXPENSE' ? sum - f.amount : sum + f.amount);

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF020C3B), Color(0xFF051970)]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          Text(DateFormat('MMM').format(date).toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 12)),
                          Text(DateFormat('dd').format(date), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 22, height: 1)),
                          const SizedBox(height: 4),
                          Text('${dailyNet.toInt()}', style: GoogleFonts.bebasNeue(color: dailyNet >= 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 10)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        children: items.map((f) {
                          dynamic player;
                          if (f.playerId != null) {
                            try {
                              player = ballProv.players.firstWhere((p) => p.id == f.playerId);
                            } catch (_) {}
                          }

                          return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.white10,
                                backgroundImage: (player != null && player.photoUrl != '') 
                                    ? MemoryImage(base64Decode(player.photoUrl)) 
                                    : null,
                                child: (player == null || player.photoUrl == '') 
                                    ? Text(f.name.isNotEmpty ? f.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 10, color: Colors.orange)) 
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(f.name, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                    if (f.note != null && f.note!.isNotEmpty)
                                      Text(f.note!, style: const TextStyle(color: Colors.white24, fontSize: 9)),
                                  ],
                                ),
                              ),
                              Text(
                                '${f.type == 'EXPENSE' ? '-' : ''}${f.amount.toInt()} ৳', 
                                style: GoogleFonts.bebasNeue(color: f.type == 'EXPENSE' ? Colors.redAccent : Colors.greenAccent, fontSize: 16)
                              ),
                              if (isAdmin) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _confirmDeleteFund(context, provider, f),
                                  child: const Icon(Icons.delete_outline, color: Colors.white10, size: 16),
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
            }).toList(),
          ],
        );
      },
    );
  }

  void _confirmDeleteFund(BuildContext context, FundProvider provider, Fund fund) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF020C3B),
        title: Text('Delete Entry', style: GoogleFonts.bebasNeue(color: Colors.white)),
        content: Text('Remove this entry of ${fund.amount.toInt()}?', style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              provider.deleteFund(fund.id!);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showAddFundDialog(BuildContext context) {
    final ballProvider = Provider.of<BallProvider>(context, listen: false);
    final players = ballProvider.players;
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String entryType = 'INCOME';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF020C3B),
          title: Text('Add to Fund', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => entryType = 'INCOME'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: entryType == 'INCOME' ? Colors.greenAccent.withOpacity(0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text('INCOME', style: GoogleFonts.bebasNeue(color: entryType == 'INCOME' ? Colors.greenAccent : Colors.white24)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => entryType = 'EXPENSE'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: entryType == 'EXPENSE' ? Colors.redAccent.withOpacity(0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text('EXPENSE', style: GoogleFonts.bebasNeue(color: entryType == 'EXPENSE' ? Colors.redAccent : Colors.white24)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') return const Iterable<String>.empty();
                    return players.where((p) => p.name.toLowerCase().contains(textEditingValue.text.toLowerCase())).map((p) => p.name);
                  },
                  onSelected: (String selection) { nameController.text = selection; },
                  fieldViewBuilder: (ctx, ctrl, focus, onSub) => TextFormField(
                    controller: ctrl,
                    focusNode: focus,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDeco('NAME / SOURCE'),
                    onChanged: (v) => nameController.text = v,
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
                            final name = options.elementAt(i);
                            final p = players.firstWhere((p) => p.name == name);
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.white10,
                                backgroundImage: p.photoUrl != '' ? MemoryImage(base64Decode(p.photoUrl)) : null,
                                child: p.photoUrl == '' ? Text(p.name[0], style: const TextStyle(fontSize: 10)) : null,
                              ),
                              title: Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                              onTap: () => onSelected(name),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco('AMOUNT'),
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
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
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
                TextField(
                  controller: noteController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco('OPTIONAL NOTE'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                String? selectedPlayerId;
                try {
                  selectedPlayerId = players.firstWhere((p) => p.name == nameController.text).id;
                } catch (_) {}

                if (nameController.text.isNotEmpty && amountController.text.isNotEmpty) {
                  final fund = Fund(
                    playerId: selectedPlayerId,
                    name: nameController.text,
                    amount: double.parse(amountController.text),
                    date: selectedDate,
                    note: noteController.text,
                    type: entryType,
                  );
                  final success = await Provider.of<FundProvider>(context, listen: false).addFund(fund);
                  if (success) {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('SAVE', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
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
