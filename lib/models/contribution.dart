import 'package:cloud_firestore/cloud_firestore.dart';

class Contribution {
  final String? id;
  final String? playerId; // New field
  final String name;
  final double taka;
  final DateTime date;
  final String monthYear;
  final String ballTape;
  final int ballCount;
  final int tapeCount;
  final bool isFinePayment; // New field

  Contribution({
    this.id,
    this.playerId,
    required this.name,
    required this.taka,
    required this.date,
    required this.monthYear,
    required this.ballTape,
    this.ballCount = 0,
    this.tapeCount = 0,
    this.isFinePayment = false, // Default to false
  });

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'name': name,
      'taka': taka,
      'date': date,
      'monthYear': monthYear,
      'ballTape': ballTape,
      'ballCount': ballCount,
      'tapeCount': tapeCount,
      'isFinePayment': isFinePayment,
    };
  }

  factory Contribution.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Contribution(
      id: docId,
      playerId: map['playerId'],
      name: map['name'] ?? '',
      taka: (map['taka'] ?? 0).toDouble(),
      date: map['date'] is DateTime ? map['date'] : (map['date'] as dynamic).toDate(),
      monthYear: map['monthYear'] ?? '',
      ballTape: map['ballTape'] ?? '',
      ballCount: map['ballCount'] ?? 0,
      tapeCount: map['tapeCount'] ?? 0,
      isFinePayment: map['isFinePayment'] ?? false,
    );
  }
}

