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
    print('getAllMembers called');
    final data = _prefs.getString(_storageKey);
    if (data != null) {
      print('Raw data from SharedPreferences: ${data.substring(0, data.length > 100 ? 100 : data.length)}...');
    } else {
      print('Raw data from SharedPreferences: null');
    }
    if (data == null) {
      print('No data found in SharedPreferences');
      return [];
    }

    try {
      final List<dynamic> jsonData = json.decode(data);
      print('Decoded JSON data count: ${jsonData.length}');

      final members = jsonData.map((data) {
        print('Processing member data: $data');
        final member = TeamMember.fromJson(data);
        print('Created member: $member');
        return member;
      }).toList();

      print('Returning ${members.length} members');
      return members;
    } catch (e) {
      print('Error decoding JSON data: $e');
      return [];
    }
  }

  Future<void> saveTeamMember(TeamMember member) async {
    final members = await getAllMembers();
    print('Members before adding: $members');
    members.add(member);
    await _saveMembers(members);
    print('Members after adding: $members');
  }

  Future<void> updateMember(TeamMember updatedMember) async {
    print('StorageService.updateMember called with ID: ${updatedMember.id}');
    print('Updated member data: $updatedMember');
    print('Email: "${updatedMember.email}"');
    print('Role: "${updatedMember.role}"');

    // Get all members
    final members = await getAllMembers();
    print('Current members count: ${members.length}');

    // Find the member to update
    final index = members.indexWhere((m) => m.id == updatedMember.id);
    print('Found member at index: $index');

    if (index != -1) {
      print('Original member: ${members[index]}');
      print('Original email: "${members[index].email}"');
      print('Original role: "${members[index].role}"');

      // Create a completely new list to avoid reference issues
      final newMembers = List<TeamMember>.from(members);

      // Replace the member at the found index
      newMembers[index] = updatedMember;

      // Save the updated list
      await _saveMembers(newMembers);
      print('Member updated and saved');

      // Verify the update
      final verifyMembers = await getAllMembers();
      final verifyMember = verifyMembers.firstWhere(
        (m) => m.id == updatedMember.id,
        orElse: () => TeamMember(
          id: 'not-found',
          name: 'Not Found',
          activeHoursStart: '09:00',
          activeHoursEnd: '17:00',
        ),
      );
      print('Verified member after update: $verifyMember');
      print('Verified email: "${verifyMember.email}"');
      print('Verified role: "${verifyMember.role}"');
    } else {
      print('Member not found with ID: ${updatedMember.id}');
      print('Available member IDs: ${members.map((m) => m.id).toList()}');
    }
  }

  Future<void> deleteMember(String id) async {
    final members = await getAllMembers();
    members.removeWhere((m) => m.id == id);
    await _saveMembers(members);
  }

  Future<void> _saveMembers(List<TeamMember> members) async {
    print('_saveMembers called with ${members.length} members');
    try {
      // Print each member's data before converting to JSON
      for (int i = 0; i < members.length; i++) {
        final member = members[i];
        print('Member $i: $member');
        print('  Email: "${member.email}"');
        print('  Role: "${member.role}"');
      }

      // Convert to JSON
      final jsonData = members.map((m) => m.toJson()).toList();

      // Print each JSON object
      for (int i = 0; i < jsonData.length; i++) {
        final json = jsonData[i];
        print('JSON $i: $json');
        print('  Email: "${json['email']}"');
        print('  Role: "${json['role']}"');
      }

      // Encode to JSON string
      final jsonString = json.encode(jsonData);
      print('JSON string length: ${jsonString.length}');

      // Save to SharedPreferences
      final result = await _prefs.setString(_storageKey, jsonString);
      print('Save result: $result');

      // Verify the data was saved correctly
      final savedData = _prefs.getString(_storageKey);
      if (savedData != null) {
        print('Saved data length: ${savedData.length}');
        final decodedData = json.decode(savedData) as List<dynamic>;
        print('Decoded data count: ${decodedData.length}');

        // Print each decoded JSON object
        for (int i = 0; i < decodedData.length; i++) {
          final decodedJson = decodedData[i];
          print('Decoded JSON $i: $decodedJson');
          print('  Email: "${decodedJson['email']}"');
          print('  Role: "${decodedJson['role']}"');
        }
      } else {
        print('WARNING: Saved data is null!');
      }
    } catch (e) {
      print('Error in _saveMembers: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> clearMembers() async {
    await _prefs.remove(_storageKey);
  }
}
