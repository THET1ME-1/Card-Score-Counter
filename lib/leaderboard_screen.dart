import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'player_profile.dart';
import 'dart:convert';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<PlayerProfile> profiles = [];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesStringList = prefs.getStringList('profiles');
    if (profilesStringList != null) {
      setState(() {
        profiles = profilesStringList.map((profileString) {
          return PlayerProfile.fromJson(jsonDecode(profileString));
        }).toList();

        // Сортировка по количеству побед
        profiles.sort((a, b) => b.wins.compareTo(a.wins));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Таблица лидеров'),
      ),
      body: ListView.builder(
        itemCount: profiles.length,
        itemBuilder: (context, index) {
          final profile = profiles[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: profile.color,
            ),
            title: Text(profile.name),
            trailing: Text('Победы: ${profile.wins}'),
          );
        },
      ),
    );
  }
}
