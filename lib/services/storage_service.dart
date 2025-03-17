import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/team_member.dart';

class StorageService {
  static final StorageService instance = StorageService._internal();
  factory StorageService() => instance;
  StorageService._internal();

  static const String _storageKey = 'team_members';
  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<List<TeamMember>> getAllMembers() async {
    final data = _prefs.getString(_storageKey);
    if (data == null) return [];

    final List<dynamic> jsonData = json.decode(data);
    return jsonData.map((data) => TeamMember.fromJson(data)).toList();
  }

  Future<void> saveTeamMember(TeamMember member) async {
    final members = await getAllMembers();
    print('Members before adding: $members');
    members.add(member);
    await _saveMembers(members);
    print('Members after adding: $members');
  }

  Future<void> updateMember(TeamMember updatedMember) async {
    final members = await getAllMembers();
    final index = members.indexWhere((m) => m.id == updatedMember.id);
    if (index != -1) {
      members[index] = updatedMember;
      await _saveMembers(members);
    }
  }

  Future<void> deleteMember(String id) async {
    final members = await getAllMembers();
    members.removeWhere((m) => m.id == id);
    await _saveMembers(members);
  }

  Future<void> _saveMembers(List<TeamMember> members) async {
    final jsonData = members.map((m) => m.toJson()).toList();
    print('Saving members: $jsonData');
    await _prefs.setString(_storageKey, json.encode(jsonData));
  }

  Future<void> clearMembers() async {
    await _prefs.remove(_storageKey);
  }
}
