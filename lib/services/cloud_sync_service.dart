import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/contribution.dart';
import '../models/fine_payment.dart';
import '../models/fund.dart';
import '../models/inventory.dart';

class CloudSyncService {
  static const String _url = 'https://script.google.com/macros/s/AKfycbxXbr2M7b1QtGtfqWEBbT3w_yr9Gs5lT6bmgzHc6IvVlw6WDiy8j1ScneYyo2zS0u7G/exec';

  static Future<bool> syncAllData({
    required List<Map<String, dynamic>> leaderboard,
    required List<Map<String, dynamic>> playerStatus,
    required List<Fund> funds,
    required List<Contribution> contributions,
    required List<FinePayment> fines,
    required List<Inventory> stock,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'leaderboard': leaderboard.asMap().entries.map((e) => [
          e.key + 1,
          e.value['name'],
          e.value['total'],
        ]).toList(),
        
        'playerStatus': playerStatus.asMap().entries.map((e) => [
          e.key + 1,
          e.value['name'],
          e.value['total'],
          e.value['totalFine'],
          e.value['paid'],
          e.value['due'],
          e.value['surplus'],
        ]).toList(),
        
        'funds': funds.map((f) => [
          DateFormat('yyyy-MM-dd').format(f.date),
          f.name,
          f.type,
          f.amount,
          f.note ?? '',
        ]).toList(),
        
        'contributions': contributions.map((c) => [
          DateFormat('yyyy-MM-dd').format(c.date),
          c.name,
          c.taka,
          c.monthYear,
          c.isFinePayment ? 'Yes' : 'No',
          c.ballTape,
        ]).toList(),
        
        'fines': fines.map((f) => [
          DateFormat('yyyy-MM-dd').format(f.date),
          f.playerName,
          f.amountPaid,
          f.monthYear,
          f.note ?? '',
        ]).toList(),
        
        'stock': stock.map((s) => [
          DateFormat('yyyy-MM-dd').format(s.date),
          s.ballsBrought,
          s.ballsTaken,
          s.totalLost,
          s.uninteniollyLost,
          s.playerLost,
          s.isStockUpdate ? s.totalStock : '-',
          s.recordedBy,
          s.note,
        ]).toList(),
      };

      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      );

      print('Sync Response Status: ${response.statusCode}');
      // Success is 200, but Apps Script sometimes redirects (302)
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      print('Cloud Sync Error: $e');
      return false;
    }
  }
}
