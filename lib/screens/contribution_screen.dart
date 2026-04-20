import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/contribution_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/ball_provider.dart';
import '../providers/fine_provider.dart';
import '../models/contribution.dart';
import '../models/fine_payment.dart';
import '../utils/status_dialog.dart';
import '../utils/export_service.dart';

class ContributionScreen extends StatefulWidget {
  const ContributionScreen({super.key});

  @override
  State<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends State<ContributionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameController = TextEditingController();
  final _takaController = TextEditingController();
  final _ballCountController = TextEditingController(text: '0');
  final _tapeCountController = TextEditingController(text: '0');
  final _infoController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedMonthYear = 'Overall';
  late List<String> _monthList;
  bool _isFinePayment = false;

  @override
  void initState() {
    super.initState();
    _generateMonthList();
    final isAdmin = Provider.of<AuthProvider>(context, listen: false).isAdmin;
    _tabController = TabController(length: isAdmin ? 3 : 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ContributionProvider>(context, listen: false).fetchContributions();
      Provider.of<FineProvider>(context, listen: false).fetchPayments();
      Provider.of<BallProvider>(context, listen: false).fetchPlayers();
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

  void _updateTotal() {
    int balls = int.tryParse(_ballCountController.text) ?? 0;
    int tapes = int.tryParse(_tapeCountController.text) ?? 0;
    int total = (balls * 40) + (tapes * 20);
    if (total > 0) _takaController.text = total.toString();
  }

  void _showAddSheet({Contribution? editItem}) {
    final players = Provider.of<BallProvider>(context, listen: false).players;
    
    if (editItem != null) {
      _selectedDate = editItem.date;
      _nameController.text = editItem.name;
      _takaController.text = editItem.taka.toInt().toString();
      _ballCountController.text = editItem.ballCount.toString();
      _tapeCountController.text = editItem.tapeCount.toString();
      _infoController.text = editItem.ballTape;
      _isFinePayment = editItem.isFinePayment;
    } else {
      _selectedDate = DateTime.now(); 
      _nameController.clear();
      _takaController.clear();
      _ballCountController.text = '0';
      _tapeCountController.text = '0';
      _infoController.clear();
      _isFinePayment = false;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          decoration: const BoxDecoration(color: Color(0xFF020C3B), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 20),
                Text(editItem == null ? 'ADD CONTRIBUTION' : 'UPDATE CONTRIBUTION', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 28, letterSpacing: 1.5)),
                const SizedBox(height: 25),
                
                GestureDetector(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null) setModalState(() => _selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Contribution Date', style: TextStyle(color: Colors.white38, fontSize: 10)),
                            Text(DateFormat('dd MMMM, yyyy').format(_selectedDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Icon(Icons.calendar_today, color: Colors.orange, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Autocomplete<String>(
                  initialValue: TextEditingValue(text: _nameController.text),
                  optionsBuilder: (v) => players.where((p) => p.name.toLowerCase().contains(v.text.toLowerCase())).map((p) => p.name),
                  onSelected: (v) => _nameController.text = v,
                  fieldViewBuilder: (ctx, focusCtrl, focus, onSub) => TextField(
                    controller: focusCtrl,
                    focusNode: focus,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDeco('Contributor Name', Icons.person_outline),
                    onChanged: (v) => _nameController.text = v,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _buildCounter('BALLS (40৳)', _ballCountController, () => setModalState(() => _updateTotal()))),
                    const SizedBox(width: 16),
                    Expanded(child: _buildCounter('TAPES (20৳)', _tapeCountController, () => setModalState(() => _updateTotal()))),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _takaController, 
                  keyboardType: TextInputType.number, 
                  style: GoogleFonts.bebasNeue(color: Colors.greenAccent, fontSize: 24), 
                  decoration: _inputDeco('Total Amount (৳)', Icons.payments_outlined),
                ),
                const SizedBox(height: 16),
                
                // NEW: Toggle for Fine Deduction
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("COUNT AS FINE?", style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 14)),
                          const Text("If ON, this amount will deduct from Fine", style: TextStyle(color: Colors.white24, fontSize: 10)),
                        ],
                      ),
                      Switch(
                        value: _isFinePayment,
                        onChanged: (val) => setModalState(() => _isFinePayment = val),
                        activeColor: Colors.orange,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _infoController, 
                  style: const TextStyle(color: Colors.white70, fontSize: 14), 
                  decoration: _inputDeco('Optional Note', Icons.note_alt_outlined),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_nameController.text.isEmpty || _takaController.text.isEmpty) return;
                      
                      int balls = int.tryParse(_ballCountController.text) ?? 0;
                      int tapes = int.tryParse(_tapeCountController.text) ?? 0;
                      
                      List<String> items = [];
                      if (balls > 0) items.add('$balls ball${balls > 1 ? "s" : ""}');
                      if (tapes > 0) items.add('$tapes tape${tapes > 1 ? "s" : ""}');
                      
                      String autoNote = items.join(", ");
                      String manualNote = _infoController.text.trim();
                      String finalNote = manualNote;
                      
                      if (autoNote.isNotEmpty && !manualNote.contains(autoNote)) {
                         if (editItem == null) {
                            finalNote = autoNote;
                            if (manualNote.isNotEmpty) finalNote = "$autoNote | $manualNote";
                         }
                      }

                      String? selectedPlayerId;
                      try {
                        selectedPlayerId = players.firstWhere((p) => p.name == _nameController.text).id;
                      } catch (_) {}

                      final c = Contribution(
                        id: editItem?.id,
                        playerId: selectedPlayerId,
                        name: _nameController.text,
                        taka: double.parse(_takaController.text),
                        date: _selectedDate,
                        monthYear: DateFormat('MM-yyyy').format(_selectedDate),
                        ballTape: finalNote,
                        ballCount: balls,
                        tapeCount: tapes,
                        isFinePayment: _isFinePayment, // Save the state
                      );
                      
                      final provider = Provider.of<ContributionProvider>(context, listen: false);
                      final success = editItem == null 
                          ? await provider.addContribution(c)
                          : await provider.updateContribution(c);

                      if (mounted) {
                        Navigator.pop(context);
                        StatusDialog.show(
                          context, 
                          message: success ? (editItem == null ? "Contribution logged." : "Contribution updated.") : "Action failed.", 
                          isSuccess: success, 
                          title: success ? "SUCCESS" : "FAILED",
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 8,
                    ),
                    child: Text(editItem == null ? 'SAVE RECORD' : 'UPDATE RECORD', style: GoogleFonts.bebasNeue(fontSize: 20, letterSpacing: 1.2, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounter(String label, TextEditingController ctrl, VoidCallback onUpdate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white24, size: 20), onPressed: () {
                int v = int.tryParse(ctrl.text) ?? 0;
                if (v > 0) ctrl.text = (v - 1).toString();
                onUpdate();
              }),
              Text(ctrl.text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.orange, size: 20), onPressed: () {
                int v = int.tryParse(ctrl.text) ?? 0;
                ctrl.text = (v + 1).toString();
                onUpdate();
              }),
            ],
          ),
        )
      ],
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      prefixIcon: Icon(icon, color: Colors.orange, size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.orange, width: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ContributionProvider>(context);
    final fineProvider = Provider.of<FineProvider>(context);
    final isAdmin = Provider.of<AuthProvider>(context).isAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text('FINANCIAL RECORDS', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24, letterSpacing: 1.5)),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.orange),
            onPressed: () async {
              try {
                if (_tabController.index == 0) {
                  final summaryData = _getUnifiedSummary(provider, fineProvider);
                  await ExportService.exportFinancialSummaryReport(monthYear: _selectedMonthYear, data: summaryData);
                } else {
                  final detailedData = _getUnifiedDetailedList(provider, fineProvider);
                  await ExportService.exportFinancialDetailedReport(monthYear: _selectedMonthYear, contributions: detailedData);
                }
                if (mounted) {
                  StatusDialog.show(context, title: "SUCCESS", message: "Financial PDF Generated!", isSuccess: true);
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
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.bebasNeue(fontSize: 14, letterSpacing: 1),
          tabs: [
            const Tab(text: 'SUMMARY'),
            const Tab(text: 'DETAILED'),
            if (isAdmin) const Tab(text: 'MANAGE'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.fetchContributions(force: true);
          await fineProvider.fetchPayments();
        },
        color: Colors.orange,
        child: Column(
          children: [
            _buildMonthPicker(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUnifiedSummary(provider, fineProvider),
                  _buildUnifiedDetailedCalendar(provider, fineProvider),
                  if (isAdmin) _buildManageTab(provider),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isAdmin ? FloatingActionButton(
        onPressed: () => _showAddSheet(), 
        backgroundColor: Colors.orange, 
        child: const Icon(Icons.add_card, color: Colors.white)
      ) : null,
    );
  }

  Map<String, Map<String, double>> _getUnifiedSummary(ContributionProvider p, FineProvider fp) {
    final contributions = p.getGroupedContributions();
    final payments = fp.payments;
    
    Map<String, Map<String, double>> unified = Map.from(contributions);

    for (var pay in payments) {
      unified.putIfAbsent(pay.monthYear, () => {});
      unified[pay.monthYear]![pay.playerName] = (unified[pay.monthYear]![pay.playerName] ?? 0) + pay.amountPaid;
    }

    if (_selectedMonthYear != 'Overall') {
      return unified.containsKey(_selectedMonthYear) ? { _selectedMonthYear: unified[_selectedMonthYear]! } : {};
    }
    return unified;
  }

  List<dynamic> _getUnifiedDetailedList(ContributionProvider p, FineProvider fp) {
    final list = _selectedMonthYear == 'Overall' 
        ? p.contributions 
        : p.contributions.where((c) => c.monthYear == _selectedMonthYear).toList();
    
    final payments = _selectedMonthYear == 'Overall'
        ? fp.payments
        : fp.payments.where((p) => p.monthYear == _selectedMonthYear).toList();

    List<dynamic> combined = [...list, ...payments];
    combined.sort((a, b) => b.date.compareTo(a.date));
    return combined;
  }

  Widget _buildUnifiedSummary(ContributionProvider p, FineProvider fp) {
    final data = _getUnifiedSummary(p, fp);

    if (data.isEmpty) return const Center(child: Text('No records found for this period', style: TextStyle(color: Colors.white24)));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: data.length,
      itemBuilder: (ctx, i) {
        String monthKey = data.keys.elementAt(i);
        Map<String, double> players = data[monthKey]!;
        double total = players.values.fold(0, (s, v) => s + v);
        
        DateTime date = DateFormat('MM-yyyy').parse(monthKey);
        String monthName = DateFormat('MMMM yyyy').format(date);

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF020C3B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(monthName.toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 22, letterSpacing: 1)),
                        Text('TOTAL COLLECTION', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text('${total.toStringAsFixed(0)} ৳', style: GoogleFonts.bebasNeue(color: Colors.greenAccent, fontSize: 24)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: players.entries.map((e) {
                    final contribs = p.contributions.where((c) => c.name == e.key && c.monthYear == monthKey).toList();
                    final fines = fp.payments.where((pay) => pay.playerName == e.key && pay.monthYear == monthKey).toList();
                    
                    String status = "";
                    if (contribs.isNotEmpty) status += "Contrib: ${contribs.length} ";
                    if (fines.isNotEmpty) status += "Fine: ${fines.length}";

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(width: 4, height: 25, decoration: BoxDecoration(color: Colors.orange.withOpacity(0.5), borderRadius: BorderRadius.circular(2))),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e.key, style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                      Text(status, style: const TextStyle(color: Colors.white24, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text('${e.value.toStringAsFixed(0)} ৳', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 20)),
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

  Widget _buildUnifiedDetailedCalendar(ContributionProvider p, FineProvider fp) {
    final combined = _getUnifiedDetailedList(p, fp);
    
    if (combined.isEmpty) return const Center(child: Text('No transactions found', style: TextStyle(color: Colors.white24)));

    // Group by Date
    Map<String, List<dynamic>> grouped = {};
    for (var item in combined) {
      String dateStr = DateFormat('yyyy-MM-dd').format(item.date);
      grouped.putIfAbsent(dateStr, () => []);
      grouped[dateStr]!.add(item);
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
              // Date Card
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
              // Items List
              Expanded(
                child: Column(
                  children: items.map((item) {
                    bool isFine = item is FinePayment;
                    bool isDeductibleContrib = item is Contribution && item.isFinePayment;
                    
                    String name = isFine ? item.playerName : item.name;
                    String note = isFine 
                        ? "Fine Collection${item.note != null && item.note!.isNotEmpty ? " | " + item.note! : ""}" 
                        : (isDeductibleContrib ? "(Fine) " : "") + item.ballTape;
                    double amount = isFine ? item.amountPaid : item.taka;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isFine || isDeductibleContrib ? Colors.greenAccent.withOpacity(0.2) : Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name.toUpperCase(), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(note, style: TextStyle(color: isFine || isDeductibleContrib ? Colors.greenAccent.withOpacity(0.5) : Colors.white38, fontSize: 9)),
                              ],
                            ),
                          ),
                          Text('${amount.toInt()} ৳', style: GoogleFonts.bebasNeue(color: isFine || isDeductibleContrib ? Colors.greenAccent : Colors.white70, fontSize: 18)),
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
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: isSelected ? const LinearGradient(colors: [Colors.orange, Colors.deepOrange]) : null,
                color: isSelected ? null : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isSelected ? Colors.orange : Colors.white10),
              ),
              alignment: Alignment.center,
              child: Text(display, style: GoogleFonts.bebasNeue(color: isSelected ? Colors.white : Colors.white38, fontSize: 14)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildManageTab(ContributionProvider p) {
    final list = _selectedMonthYear == 'Overall' 
        ? p.contributions 
        : p.contributions.where((c) => c.monthYear == _selectedMonthYear).toList();
    
    if (list.isEmpty) return const Center(child: Text('No records found', style: TextStyle(color: Colors.white24)));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final item = list[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05), 
            borderRadius: BorderRadius.circular(20), 
            border: Border.all(color: Colors.white10)
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${DateFormat('dd MMM yyyy').format(item.date)} | ${item.taka.toStringAsFixed(0)}৳', style: const TextStyle(color: Colors.orange, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                onPressed: () => _showAddSheet(editItem: item),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: () => _showDeleteConfirm(item.id!, p),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirm(String id, ContributionProvider p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF020C3B),
        title: Text('DELETE CONTRIBUTION?', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1)),
        content: const Text('Are you sure you want to remove this transaction record?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              p.deleteContribution(id);
              Navigator.pop(context);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
