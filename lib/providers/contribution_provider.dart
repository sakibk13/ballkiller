import 'package:flutter/material.dart';
import '../models/contribution.dart';
import '../services/database_service.dart';

class ContributionProvider with ChangeNotifier {
  List<Contribution> _contributions = [];
  bool _isLoading = false;

  List<Contribution> get contributions => _contributions;
  bool get isLoading => _isLoading;

  Future<void> fetchContributions({bool force = false}) async {
    if (!force && _contributions.isNotEmpty) return;

    _isLoading = true;
    notifyListeners();
    try {
      _contributions = await DatabaseService().getContributions();
    } catch (e) {
      debugPrint('Fetch Contributions Error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addContribution(Contribution contribution) async {
    _isLoading = true;
    notifyListeners();
    bool success = false;
    try {
      success = await DatabaseService().addContribution(contribution);
      if (success) {
        await fetchContributions(force: true);
      }
    } catch (e) {
      debugPrint('Add Contribution Error: $e');
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> updateContribution(Contribution contribution) async {
    _isLoading = true;
    notifyListeners();
    bool success = false;
    try {
      success = await DatabaseService().updateContribution(contribution);
      if (success) {
        await fetchContributions(force: true);
      }
    } catch (e) {
      debugPrint('Update Contribution Error: $e');
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<void> deleteContribution(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await DatabaseService().deleteContribution(id);
      await fetchContributions(force: true);
    } catch (e) {
      debugPrint('Delete Contribution Error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  // Returns data grouped by monthYear, then by person name
  // {"04-2024": {"Shakib": 500, "Rakib": 300}}
  Map<String, Map<String, double>> getGroupedContributions() {
    Map<String, Map<String, double>> grouped = {};
    for (var contrib in _contributions) {
      if (!grouped.containsKey(contrib.monthYear)) {
        grouped[contrib.monthYear] = {};
      }
      grouped[contrib.monthYear]![contrib.name] = (grouped[contrib.monthYear]![contrib.name] ?? 0) + contrib.taka;
    }
    return grouped;
  }

  Map<String, double> getMonthWiseTotal() {
    Map<String, double> monthlyTotals = {};
    for (var contrib in _contributions) {
      monthlyTotals[contrib.monthYear] = (monthlyTotals[contrib.monthYear] ?? 0) + contrib.taka;
    }
    return monthlyTotals;
  }

  double getTotalForPlayer(String? playerId, String monthYear) {
    if (playerId == null) return 0;
    
    if (monthYear == 'Overall') {
      return _contributions
          .where((c) => c.playerId == playerId)
          .fold(0.0, (sum, c) => sum + c.taka);
    }
    
    return _contributions
        .where((c) => c.playerId == playerId && c.monthYear == monthYear)
        .fold(0.0, (sum, c) => sum + c.taka);
  }
}
