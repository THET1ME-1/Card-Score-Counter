import 'dart:io';
import 'package:flutter/material.dart';

class PlayerProfile {
  String name;
  Color color;
  int wins;
  String? imagePath;

  PlayerProfile({
    required this.name,
    required this.color,
    this.wins = 0,
    this.imagePath,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      name: json['name'],
      color: Color(json['color']),
      wins: json['wins'] ?? 0,
      imagePath: json['imagePath'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'color': color.toARGB32(),
      'wins': wins,
      'imagePath': imagePath,
    };
  }

  Widget getAvatar({double radius = 20}) {
    if (imagePath != null && File(imagePath!).existsSync()) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(imagePath!)),
        backgroundColor: color,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(color: Colors.white, fontSize: radius * 0.7),
      ),
    );
  }
}
