import 'package:flutter/material.dart';

class PlayerProfile {
  String name;
  Color color;
  int wins;

  PlayerProfile({required this.name, required this.color, this.wins = 0});

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      name: json['name'],
      color: Color(json['color']),
      wins: json['wins'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'color': color.value,
      'wins': wins,
    };
  }
}
