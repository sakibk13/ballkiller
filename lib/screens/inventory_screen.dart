import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/inventory_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/ball_provider.dart';
import '../models/inventory.dart';
import '../utils/status_dialog.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late bool _isAdmin;
  final _ballBoughtController = TextEditingController(text: '0');
  final _tapeBoughtController = TextEditingController(text: '0');
  final _ballTakenController = TextEditingController(text: '0');
  final _totalLostController = TextEditingController(text: '0');
  final _uninteniollyLostController = TextEditingController(text: '0');
  final _totalStockController = TextEditingController(text: '0');
  final _noteController = TextEditingController();
  
  bool _isStockUpdate = false;
  DateTime _selectedDate = DateTime.now();
  String _selectedMonthYear = 'Overall';
  late List<String> _monthList;

  @override
  void initState() {
    super.initState();
    _generateMonthList();
    _isAdmin = Provider.of<AuthProvider>(context, listen: false).isAdmin;
    // Only 1 tab for non-admins (SUMMARY), 3 for admins
    _tabController = TabController(length: _isAdmin ? 3 : 1, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).fetchInventory();
      Provider.of<BallProvider>(context, listen: false).init();
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
  void dispose() {
    _tabController.dispose();
    _ballBoughtController.dispose();
    _tapeBoughtController.dispose();
    _ballTakenController.dispose();
    _totalLostController.dispose();
    _uninteniollyLostController.dispose();
    _totalStockController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _showStatusDialog(String message, bool isSuccess) {
    StatusDialog.show(
      context, 
      message: message, 
      isSuccess: isSuccess, 
      title: isSuccess ? "RECORD SAVED" : "ERROR",
    );
  }

  void _resetControllers() {
    _ballBoughtController.text = '0';
    _tapeBoughtController.text = '0';
    _ballTakenController.text = '0';
    _totalLostController.text = '0';
    _uninteniollyLostController.text = '0';
    _totalStockController.text = '0';
    _noteController.clear();
  }

  void _showAddInventorySheet({Inventory? editItem}) {
    if (editItem != null) {
      _selectedDate = editItem.date;
      _isStockUpdate = editItem.isStockUpdate;
      _ballBoughtController.text = editItem.ballsBrought.toString();
      _tapeBoughtController.text = editItem.tapesBrought.toString();
      _ballTakenController.text = editItem.ballsTaken.toString();
      _totalLostController.text = editItem.totalLost.toString();
      _uninteniollyLostController.text = editItem.uninteniollyLost.toString();
      _totalStockController.text = editItem.totalStock.toString();
      _noteController.text = editItem.note;
    } else {
      _selectedDate = DateTime.now(); 
      _isStockUpdate = false;
      _resetControllers();
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          int playerLost = int.tryParse(_totalLostController.text) ?? 0;
          int uninLost = int.tryParse(_uninteniollyLostController.text) ?? 0;
          int totalLostCalculated = playerLost + uninLost;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24, right: 24, top: 24,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF020C3B), 
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5)],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(editItem == null ? 'NEW INVENTORY LOG' : 'UPDATE RECORD', 
                        style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 28, letterSpacing: 1.5)),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white38)),
                    ],
                  ),
                  const SizedBox(height: 25),
                  
                  // Date Picker
                  GestureDetector(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2101));
                      if (picked != null) setModalState(() => _selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('LOG DATE', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(DateFormat('dd MMMM, yyyy').format(_selectedDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Icon(Icons.calendar_today_rounded, color: Colors.orange, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SwitchListTile(
                    title: const Text('Manual Stock Reset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Override all calculations with manual stock', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    value: _isStockUpdate, activeThumbColor: Colors.orange, contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setModalState(() => _isStockUpdate = v),
                  ),
                  const SizedBox(height: 10),

                  if (_isStockUpdate) ...[
                    _buildSectionHeader('STOCK OVERRIDE', Icons.inventory_2_rounded),
                    _buildInput(_totalStockController, 'Current Stock Count', Icons.numbers, onChanged: (v) => setModalState(() {})),
                    const SizedBox(height: 12),
                    _buildInput(_noteController, 'Reason/Note', Icons.note_alt_outlined, isNumber: false),
                  ] else ...[
                    // Section 1: PURCHASE
                    _buildSectionHeader('PURCHASE RECORD', Icons.shopping_cart_checkout),
                    Row(
                      children: [
                        Expanded(child: _buildInput(_ballBoughtController, 'Balls Bought', Icons.add_circle_outline)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInput(_tapeBoughtController, 'Tapes Bought', Icons.layers_outlined)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section 2: SESSION LOG
                    _buildSectionHeader('SESSION LOG', Icons.sports_cricket_rounded),
                    _buildInput(_ballTakenController, 'Balls Taken for Session', Icons.outbox_rounded),
                    const SizedBox(height: 20),

                    // Section 3: LOSS ACCOUNTABILITY
                    _buildSectionHeader('LOSS ACCOUNTABILITY', Icons.analytics_rounded),
                    Row(
                      children: [
                        Expanded(child: _buildInput(_totalLostController, 'Player Lost', Icons.person_remove_outlined, onChanged: (v) => setModalState(() {}))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInput(_uninteniollyLostController, 'Unintentional', Icons.error_outline, onChanged: (v) => setModalState(() {}))),
                      ],
                    ),
                    const SizedBox(height: 15),
                    
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Text('TOTAL LOST (CALCULATED)', style: GoogleFonts.bebasNeue(color: Colors.redAccent, fontSize: 16, letterSpacing: 1)),
                          Text('$totalLostCalculated', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 32)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildInput(_noteController, 'Session Notes (Optional)', Icons.notes, isNumber: false),
                  ],
                  
                  const SizedBox(height: 35),
                  SizedBox(
                    width: double.infinity, height: 60,
                    child: ElevatedButton(
                      onPressed: () async {
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        
                        int ballsBrought = _isStockUpdate ? 0 : (int.tryParse(_ballBoughtController.text) ?? 0);
                        int tapesBrought = _isStockUpdate ? 0 : (int.tryParse(_tapeBoughtController.text) ?? 0);
                        int ballsTaken = _isStockUpdate ? 0 : (int.tryParse(_ballTakenController.text) ?? 0);
                        
                        int playerLost = _isStockUpdate ? 0 : (int.tryParse(_totalLostController.text) ?? 0);
                        int uninteniollyLost = _isStockUpdate ? 0 : (int.tryParse(_uninteniollyLostController.text) ?? 0);
                        int totalLost = playerLost + uninteniollyLost;

                        final inv = Inventory(
                          id: editItem?.id,
                          date: _selectedDate,
                          ballsBrought: ballsBrought,
                          tapesBrought: tapesBrought,
                          ballsTaken: ballsTaken,
                          totalLost: totalLost,
                          uninteniollyLost: uninteniollyLost,
                          playerLost: playerLost,
                          totalStock: _isStockUpdate ? (int.tryParse(_totalStockController.text) ?? 0) : 0,
                          isStockUpdate: _isStockUpdate,
                          note: _noteController.text,
                          monthYear: DateFormat('MM-yyyy').format(_selectedDate),
                          recordedBy: auth.currentUser?.name ?? 'Admin',
                        );
                        
                        final provider = Provider.of<InventoryProvider>(context, listen: false);
                        final success = editItem == null 
                            ? await provider.addInventory(inv)
                            : await provider.updateInventory(inv);

                        if (mounted) {
                          Navigator.pop(context);
                          _showStatusDialog(success ? (editItem == null ? "Inventory record saved!" : "Record updated!") : "Failed to process request.", success);
                          if (success) _resetControllers();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
                        elevation: 8,
                        shadowColor: Colors.orange.withOpacity(0.5),
                      ),
                      child: Text(editItem == null ? 'CONFIRM & SAVE' : 'UPDATE RECORD', style: GoogleFonts.bebasNeue(fontSize: 20, letterSpacing: 1.2, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 14, letterSpacing: 1)),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: Colors.white10)),
        ],
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, IconData icon, {bool isNumber = true, Function(String)? onChanged}) {
    return TextField(
      controller: ctrl, 
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.orange, size: 20),
        filled: true, fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.orange)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invProvider = Provider.of<InventoryProvider>(context);
    final ballProvider = Provider.of<BallProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text('STOCK LOG', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24, letterSpacing: 1.5)),
        backgroundColor: const Color(0xFF020C3B), elevation: 0,
        bottom: TabBar(
          controller: _tabController, 
          indicatorColor: Colors.orange, 
          labelColor: Colors.orange, 
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.bebasNeue(fontSize: 14, letterSpacing: 1),
          tabs: [
            const Tab(text: 'SUMMARY'),
            if (_isAdmin) const Tab(text: 'HISTORY'),
            if (_isAdmin) const Tab(text: 'MANAGE'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async { 
          await invProvider.fetchInventory(force: true); 
          await ballProvider.refresh();
        },
        color: Colors.orange,
        child: TabBarView(
          controller: _tabController,
          children: [ 
            _buildSummary(invProvider, ballProvider), 
            if (_isAdmin) _buildHistory(invProvider),
            if (_isAdmin) _buildManageTab(invProvider),
          ],
        ),
      ),
      floatingActionButton: _isAdmin ? FloatingActionButton(onPressed: () => _showAddInventorySheet(), backgroundColor: Colors.orange, child: const Icon(Icons.add_chart, color: Colors.white)) : null,
    );
  }

  Widget _buildManageTab(InventoryProvider inv) {
    final list = inv.inventoryList;
    if (list.isEmpty) return const Center(child: Text('No records found', style: TextStyle(color: Colors.white24)));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final item = list[i];
        final bool isStock = item.isStockUpdate;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('dd MMM, yyyy').format(item.date), style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 16)),
                    Text(
                      isStock ? 'STOCK UPDATE' : 'LOG: B:${item.ballsBrought} T:${item.ballsTaken} L:${item.totalLost}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text('By: ${item.recordedBy}', style: const TextStyle(color: Colors.white24, fontSize: 9)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20), onPressed: () => _showAddInventorySheet(editItem: item)),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 20), onPressed: () => _showDeleteConfirm(item.id!, inv)),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirm(String id, InventoryProvider inv) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF020C3B),
        title: Text('DELETE RECORD?', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1)),
        content: const Text('This action cannot be undone. Remove this inventory log?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              inv.deleteInventory(id);
              Navigator.pop(context);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(InventoryProvider inv, BallProvider ball) {
    final totals = inv.getMonthlyTotals()[_selectedMonthYear] ?? {'bought': 0, 'tape': 0, 'taken': 0, 'totalLost': 0, 'unin': 0, 'player': 0};
    final remaining = inv.getCumulativeRemaining(_selectedMonthYear);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildMonthPicker(),
          const SizedBox(height: 25),
          
          _buildStockNotice(totals['totalLost'] ?? 0, totals['player'] ?? 0, totals['unin'] ?? 0),
          const SizedBox(height: 25),

          Row(
            children: [
              Expanded(child: _buildStatCard('BOUGHT', '${totals['bought']}', Colors.blue, Icons.shopping_bag)),
              const SizedBox(width: 15),
              Expanded(child: _buildStatCard('TAPES', '${totals['tape']}', Colors.purpleAccent, Icons.layers_outlined)),
            ],
          ),
          const SizedBox(height: 15),
          
          Row(
            children: [
              Expanded(child: _buildStatCard('TOTAL LOST', '${totals['totalLost']}', Colors.redAccent, Icons.auto_delete)),
              const SizedBox(width: 15),
              Expanded(child: _buildStatCard('CURRENT STOCK', '$remaining', Colors.greenAccent, Icons.inventory_2)),
            ],
          ),
          
          if (_isAdmin) ...[
            const SizedBox(height: 35),
            Row(
              children: [ 
                Container(width: 4, height: 20, color: Colors.orange), 
                const SizedBox(width: 10), 
                Text('MONTHLY DATA LOG', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1)) 
              ],
            ),
            const SizedBox(height: 15),
            _buildTable(inv.getItemsForMonth(_selectedMonthYear)),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildStockNotice(int total, int player, int unin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 10),
              Text('LOSS BREAKDOWN NOTICE', style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 18, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            'The total lost count ($total) is the combined value of players responsible loss ($player) and unintentional/ground loss ($unin).',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _noticeDetail('PLAYER LOST', player, Colors.orangeAccent),
              const Text('+', style: TextStyle(color: Colors.white24, fontSize: 20)),
              _noticeDetail('UNINTENTIONAL', unin, Colors.redAccent),
              const Text('=', style: TextStyle(color: Colors.white24, fontSize: 20)),
              _noticeDetail('TOTAL LOST', total, Colors.white),
            ],
          )
        ],
      ),
    );
  }

  Widget _noticeDetail(String label, int val, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 10)),
        Text('$val', style: GoogleFonts.bebasNeue(color: color, fontSize: 24)),
      ],
    );
  }

  Widget _buildStatCard(String label, String val, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05), 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)],
      ),
      child: Column(
        children: [ 
          Icon(icon, color: color, size: 24), 
          const SizedBox(height: 12), 
          Text(label, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)), 
          FittedBox(child: Text(val, style: GoogleFonts.bebasNeue(color: color, fontSize: 28, letterSpacing: 1))) 
        ],
      ),
    );
  }

  Widget _buildMonthPicker() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal, itemCount: _monthList.length,
        itemBuilder: (context, index) {
          final m = _monthList[index]; final isSelected = _selectedMonthYear == m;
          String display = m == 'Overall' ? 'OVERALL' : DateFormat('MMM yy').format(DateFormat('MM-yyyy').parse(m)).toUpperCase();
          return GestureDetector(
            onTap: () => setState(() => _selectedMonthYear = m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: isSelected ? const LinearGradient(colors: [Colors.orange, Colors.deepOrange]) : null, 
                color: isSelected ? null : Colors.white.withOpacity(0.05), 
                borderRadius: BorderRadius.circular(15), 
                border: Border.all(color: isSelected ? Colors.orange : Colors.white10),
                boxShadow: isSelected ? [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10)] : null,
              ),
              alignment: Alignment.center, child: Text(display, style: GoogleFonts.bebasNeue(color: isSelected ? Colors.white : Colors.white38, fontSize: 15, letterSpacing: 1)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTable(List<Inventory> items) {
    if (items.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(30), child: Text('No records for this month', style: GoogleFonts.poppins(color: Colors.white24, fontSize: 12))));
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 40, horizontalMargin: 24, headingRowHeight: 56, headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
            columns: [
              DataColumn(label: Text('DATE', style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 12, letterSpacing: 1.2))),
              DataColumn(label: Text('BOUGHT', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 12, letterSpacing: 1.2))),
              DataColumn(label: Text('TAKEN', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 12, letterSpacing: 1.2))),
              DataColumn(label: Text('LOST', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 12, letterSpacing: 1.2))),
              DataColumn(label: Text('UNIN', style: GoogleFonts.bebasNeue(color: Colors.redAccent, fontSize: 12, letterSpacing: 1.2))),
              DataColumn(label: Text('PLAYER', style: GoogleFonts.bebasNeue(color: Colors.orangeAccent, fontSize: 12, letterSpacing: 1.2))),
              DataColumn(label: Text('SESS REM', style: GoogleFonts.bebasNeue(color: Colors.greenAccent, fontSize: 12, letterSpacing: 1.2))),
            ],
            rows: items.map((item) {
              int sessionRem = item.ballsTaken - item.totalLost;
              return DataRow(cells: [
                DataCell(Text(DateFormat('dd MMM').format(item.date), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                DataCell(Text(item.isStockUpdate ? '-' : '${item.ballsBrought}', style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold))),
                DataCell(Text(item.isStockUpdate ? '-' : '${item.ballsTaken}', style: const TextStyle(color: Colors.purpleAccent, fontSize: 13, fontWeight: FontWeight.bold))),
                DataCell(Text(item.isStockUpdate ? '-' : '${item.totalLost}', style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold))),
                DataCell(Text(item.isStockUpdate ? '-' : '${item.uninteniollyLost}', style: const TextStyle(color: Colors.white70, fontSize: 12))),
                DataCell(Text(item.isStockUpdate ? '-' : '${item.playerLost}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.isStockUpdate ? '${item.totalStock}' : '$sessionRem', 
                      style: GoogleFonts.bebasNeue(color: Colors.greenAccent, fontSize: 18, letterSpacing: 1)
                    ),
                  )
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildHistory(InventoryProvider inv) {
    final list = inv.inventoryList;
    if (list.isEmpty) return const Center(child: Text('No history found', style: TextStyle(color: Colors.white24)));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16), itemCount: list.length,
      itemBuilder: (context, i) {
        final item = list[i]; final bool isStock = item.isStockUpdate;
        int sessionRem = item.ballsTaken - item.totalLost;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF020C3B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isStock ? Colors.greenAccent.withOpacity(0.3) : Colors.white10),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event_note_rounded, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Text(DateFormat('EEEE, dd MMMM yyyy').format(item.date).toUpperCase(), 
                          style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 14, letterSpacing: 1)),
                      ],
                    ),
                    if (isStock)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text('STOCK RESET', style: GoogleFonts.bebasNeue(color: Colors.greenAccent, fontSize: 10)),
                      ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (isStock) ...[
                      _historySection('PURCHASE RECORD', [
                        _historyStat('BOUGHT', '-', Colors.blue),
                        _historyStat('TAPES', '-', Colors.purpleAccent),
                      ]),
                      const Divider(color: Colors.white10, height: 30),
                      _historySection('STOCK ACCOUNTABILITY', [
                        _historyStat('MANUAL STOCK', '${item.totalStock}', Colors.greenAccent),
                        _historyStat('REASON', item.note.isEmpty ? 'Manual Update' : item.note, Colors.orangeAccent, flex: 2),
                      ]),
                    ] else ...[
                      _historySection('PURCHASE RECORD', [
                        _historyStat('BOUGHT', '${item.ballsBrought}', Colors.blue),
                        _historyStat('TAPES', '${item.tapesBrought}', Colors.purpleAccent),
                      ]),
                      const Divider(color: Colors.white10, height: 30),
                      _historySection('SESSION LOG', [
                        _historyStat('TAKEN', '${item.ballsTaken}', Colors.orangeAccent),
                        _historyStat('REMAINING', '$sessionRem', Colors.greenAccent),
                      ]),
                      const Divider(color: Colors.white10, height: 30),
                      _historySection('LOSS ACCOUNTABILITY', [
                        _historyStat('TOTAL LOST', '${item.totalLost}', Colors.redAccent),
                        _historyStat('UNINTENTIONAL', '${item.uninteniollyLost}', Colors.white70),
                        _historyStat('PLAYER RESP', '${item.playerLost}', Colors.orange),
                      ]),
                    ],
                    
                    if (!isStock && item.note.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(12)),
                        child: Text(item.note, style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
                      ),
                    ],
                  ],
                ),
              ),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('RECORDED BY ', style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
                    Text(item.recordedBy.toUpperCase(), style: const TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _historySection(String title, List<Widget> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 12, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        Row(children: stats),
      ],
    );
  }

  Widget _historyStat(String label, String val, Color color, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(val, style: GoogleFonts.bebasNeue(color: color, fontSize: 18)),
        ],
      ),
    );
  }
}
