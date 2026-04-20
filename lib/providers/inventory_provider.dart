import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inventory.dart';
import '../services/database_service.dart';

class InventoryProvider with ChangeNotifier {
  List<Inventory> _inventoryList = [];
  bool _isLoading = false;

  List<Inventory> get inventoryList => _inventoryList;
  bool get isLoading => _isLoading;

  Future<void> fetchInventory({bool force = false}) async {
    if (!force && _inventoryList.isNotEmpty) return;
    
    _isLoading = true;
    notifyListeners();
    try {
      _inventoryList = await DatabaseService().getInventory();
    } catch (e) {
      debugPrint('Fetch Inventory Error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await fetchInventory(force: true);
  }

  Future<bool> addInventory(Inventory inventory) async {
    _isLoading = true;
    notifyListeners();
    bool success = false;
    try {
      success = await DatabaseService().addInventory(inventory);
      if (success) {
        await refresh();
      }
    } catch (e) {
      debugPrint('Add Inventory Error: $e');
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> updateInventory(Inventory inventory) async {
    _isLoading = true;
    notifyListeners();
    bool success = false;
    try {
      success = await DatabaseService().updateInventory(inventory);
      if (success) {
        await refresh();
      }
    } catch (e) {
      debugPrint('Update Inventory Error: $e');
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<void> deleteInventory(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await DatabaseService().deleteInventory(id);
      await refresh();
    } catch (e) {
      debugPrint('Delete Inventory Error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Map<String, Map<String, int>> getMonthlyTotals() {
    Map<String, Map<String, int>> totals = {
      "Overall": {"bought": 0, "tape": 0, "taken": 0, "totalLost": 0, "unin": 0, "player": 0}
    };
    
    for (var item in _inventoryList) {
      if (!totals.containsKey(item.monthYear)) {
        totals[item.monthYear] = {"bought": 0, "tape": 0, "taken": 0, "totalLost": 0, "unin": 0, "player": 0};
      }
      if (!item.isStockUpdate) {
        // Add to specific month
        totals[item.monthYear]!["bought"] = totals[item.monthYear]!["bought"]! + item.ballsBrought;
        totals[item.monthYear]!["tape"] = totals[item.monthYear]!["tape"]! + item.tapesBrought;
        totals[item.monthYear]!["taken"] = totals[item.monthYear]!["taken"]! + item.ballsTaken;
        totals[item.monthYear]!["totalLost"] = totals[item.monthYear]!["totalLost"]! + item.totalLost;
        totals[item.monthYear]!["unin"] = totals[item.monthYear]!["unin"]! + item.uninteniollyLost;
        totals[item.monthYear]!["player"] = totals[item.monthYear]!["player"]! + item.playerLost;

        // Add to Overall
        totals["Overall"]!["bought"] = totals["Overall"]!["bought"]! + item.ballsBrought;
        totals["Overall"]!["tape"] = totals["Overall"]!["tape"]! + item.tapesBrought;
        totals["Overall"]!["taken"] = totals["Overall"]!["taken"]! + item.ballsTaken;
        totals["Overall"]!["totalLost"] = totals["Overall"]!["totalLost"]! + item.totalLost;
        totals["Overall"]!["unin"] = totals["Overall"]!["unin"]! + item.uninteniollyLost;
        totals["Overall"]!["player"] = totals["Overall"]!["player"]! + item.playerLost;
      }
    }
    return totals;
  }

  // Calculate stock dynamically: 
  // Latest Manual Stock Update - Sum(Total Lost) since that manual update.
  // Note: 'Bought' is now separate and doesn't auto-increase stock unless user does a manual reset.
  int getCumulativeRemaining(String upToMonthYear) {
    if (_inventoryList.isEmpty) return 0;

    List<Inventory> filtered = _inventoryList;
    if (upToMonthYear != 'Overall') {
      try {
        DateTime limitDate = DateFormat('MM-yyyy').parse(upToMonthYear);
        DateTime endOfMonth = DateTime(limitDate.year, limitDate.month + 1, 0, 23, 59, 59);
        filtered = _inventoryList.where((item) => item.date.isBefore(endOfMonth)).toList();
      } catch (e) {
        debugPrint('Limit Date Parse Error: $e');
      }
    }

    if (filtered.isEmpty) return 0;

    List<Inventory> sorted = List.from(filtered);
    sorted.sort((a, b) => a.date.compareTo(b.date));

    int currentStock = 0;
    
    for (var item in sorted) {
      if (item.isStockUpdate) {
        currentStock = item.totalStock;
      }
      // Note: totalLost is no longer deducted automatically as per user request
    }
    
    return currentStock;
  }

  int getUninteniollyLostForMonth(String monthYear) {
    final totals = getMonthlyTotals();
    if (monthYear == 'Overall') {
      return totals.values.fold(0, (sum, m) => sum + (m['unin'] ?? 0));
    }
    return totals[monthYear]?['unin'] ?? 0;
  }

  List<Inventory> getItemsForMonth(String monthYear) {
    if (monthYear == 'Overall') return _inventoryList;
    return _inventoryList.where((item) => item.monthYear == monthYear).toList();
  }
}
