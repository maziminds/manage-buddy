import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'models/team_member.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await StorageService.instance.init();
  runApp(const MyApp());
}

class RoleInfo {
  final String name;
  final Color color;

  const RoleInfo(this.name, this.color);
}

final Map<String, RoleInfo> roleInfos = {
  'developer': RoleInfo('Developer', Colors.blue),
  '3d_artist': RoleInfo('3D Artist', Colors.purple),
  '2d_artist': RoleInfo('2D Artist', Colors.green),
  'composer': RoleInfo('Composer', Colors.orange),
};

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manage Buddy',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      home: const TeamListPage(),
    );
  }
}

class TeamListPage extends StatefulWidget {
  const TeamListPage({super.key});

  @override
  State<TeamListPage> createState() => _TeamListPageState();
}

class _TeamListPageState extends State<TeamListPage> {
  List<TeamMember> _members = [];
  String? _selectedRoleFilter;
  bool? _activeFilter;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final members = await StorageService.instance.getAllMembers();
    setState(() {
      _members = members;
    });
  }

  List<TeamMember> get _filteredMembers {
    return _members.where((member) {
      if (_selectedRoleFilter != null && member.role != _selectedRoleFilter) {
        return false;
      }
      if (_activeFilter != null) {
        final isActive = _isMemberActive(member);
        if (isActive != _activeFilter) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  bool _isMemberActive(TeamMember member) {
    final memberTz = member.timezone != null ? tz.getLocation(member.timezone!) : tz.getLocation('UTC');
    final now = tz.TZDateTime.now(memberTz);
    final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);

    // Parse member's active hours
    final format = DateFormat('HH:mm');
    final startTime = TimeOfDay.fromDateTime(format.parse(member.activeHoursStart));
    final endTime = TimeOfDay.fromDateTime(format.parse(member.activeHoursEnd));

    // Convert all times to minutes since midnight for easy comparison
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;

    if (endMinutes > startMinutes) {
      // Normal case: start time is before end time
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Special case: end time is on the next day
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) {
      return '?'; // Return a placeholder for empty names
    }
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color _getStatusColor(bool isActive) {
    return isActive ? Colors.green.shade700 : Colors.grey.shade400;
  }

  String _formatTimezoneOffset(String timezone) {
    final location = tz.getLocation(timezone);
    final offsetInSeconds = location.currentTimeZone.offset ~/ 1000;
    final absSeconds = offsetInSeconds.abs();
    final hours = absSeconds ~/ 3600;
    final minutes = (absSeconds % 3600) ~/ 60;

    final sign = offsetInSeconds >= 0 ? '+' : '-';
    return 'GMT$sign${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  Future<void> _showDeleteConfirmation(BuildContext context, TeamMember member) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Member'),
          content: Text('Are you sure you want to delete ${member.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await StorageService.instance.deleteMember(member.id);
                if (mounted) {
                  Navigator.of(context).pop();
                  _loadMembers();
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredMembers = _filteredMembers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Buddy'),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: const Center(
                child: Text(
                  'Filters',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Filter by Role',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...roleInfos.entries.map((entry) => RadioListTile<String>(
                    title: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: entry.value.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(entry.value.name),
                      ],
                    ),
                    value: entry.key,
                    groupValue: _selectedRoleFilter,
                    onChanged: (value) {
                      setState(() {
                        _selectedRoleFilter = value;
                      });
                      Navigator.pop(context);
                    },
                  )),
                  RadioListTile<String?>(
                    title: const Text('All Roles'),
                    value: null,
                    groupValue: _selectedRoleFilter,
                    onChanged: (value) {
                      setState(() {
                        _selectedRoleFilter = value;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Filter by Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  RadioListTile<bool?>(
                    title: Row(
                      children: [
                        Icon(Icons.circle, size: 12, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text('Active Only'),
                      ],
                    ),
                    value: true,
                    groupValue: _activeFilter,
                    onChanged: (value) {
                      setState(() {
                        _activeFilter = value;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  RadioListTile<bool?>(
                    title: Row(
                      children: [
                        Icon(Icons.circle, size: 12, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('Inactive Only'),
                      ],
                    ),
                    value: false,
                    groupValue: _activeFilter,
                    onChanged: (value) {
                      setState(() {
                        _activeFilter = value;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  RadioListTile<bool?>(
                    title: const Text('All Members'),
                    value: null,
                    groupValue: _activeFilter,
                    onChanged: (value) {
                      setState(() {
                        _activeFilter = value;
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            if (_selectedRoleFilter != null || _activeFilter != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedRoleFilter = null;
                      _activeFilter = null;
                    });
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear All Filters'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: filteredMembers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No team members found',
                    style: TextStyle(fontSize: 18),
                  ),
                  if (_selectedRoleFilter != null || _activeFilter != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Try adjusting your filters',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ],
              ),
            )
          : ListView.builder(
              itemCount: filteredMembers.length,
              itemBuilder: (context, index) {
                final member = filteredMembers[index];
                final roleInfo = roleInfos[member.role] ?? RoleInfo('Unknown Role', Colors.grey);
                final memberTz = member.timezone != null ? tz.getLocation(member.timezone!) : tz.getLocation('UTC');
                final localTime = tz.TZDateTime.now(memberTz);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: _getStatusColor(_isMemberActive(member)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _isMemberActive(member) ? roleInfo.color : Colors.grey,
                      child: Text(
                        _getInitials(member.name ?? ''),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(member.name ?? 'Unnamed'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: roleInfo.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(roleInfo.name),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 12,
                              color: _isMemberActive(member) ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isMemberActive(member) ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: _isMemberActive(member) ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Local time: ${DateFormat('HH:mm').format(localTime)}',
                              style: TextStyle(color: Colors.black),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.black),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditMemberPage(member: member),
                              ),
                            );
                            _loadMembers();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _showDeleteConfirmation(context, member),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => MemberDetailPage(member: member),
                      ));
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddMemberPage()),
          );
          _loadMembers();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddMemberPage extends StatefulWidget {
  const AddMemberPage({super.key});

  @override
  State<AddMemberPage> createState() => _AddMemberPageState();
}

class _AddMemberPageState extends State<AddMemberPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedRole;
  String? _selectedTimezone;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  final Map<TextEditingController, TextEditingController> _customFieldControllers = {};
  bool _isNotReadyYet = false;

  final List<String> _roles = roleInfos.keys.toList();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    for (var controllers in _customFieldControllers.entries) {
      controllers.key.dispose();
      controllers.value.dispose();
    }
    super.dispose();
  }

  void _addCustomField() {
    setState(() {
      _customFieldControllers[TextEditingController()] = TextEditingController();
    });
  }

  void _removeCustomField(TextEditingController keyController) {
    setState(() {
      final valueController = _customFieldControllers.remove(keyController);
      keyController.dispose();
      valueController?.dispose();
    });
  }

  Map<String, String> _getCustomFields() {
    final customFields = <String, String>{};
    for (var entry in _customFieldControllers.entries) {
      final key = entry.key.text.trim();
      final value = entry.value.text.trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        customFields[key] = value;
      }
    }
    return customFields;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimezoneOffset(String timezone) {
    final location = tz.getLocation(timezone);
    final offsetInSeconds = location.currentTimeZone.offset ~/ 1000;
    final absSeconds = offsetInSeconds.abs();
    final hours = absSeconds ~/ 3600;
    final minutes = (absSeconds % 3600) ~/ 60;

    final sign = offsetInSeconds >= 0 ? '+' : '-';
    return 'GMT$sign${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Team Member'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (!_isNotReadyYet && (value == null || value.isEmpty)) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (!_isNotReadyYet && (value == null || value.isEmpty)) {
                  return 'Please enter an email';
                }
                if (!_isNotReadyYet && value != null && !value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              items: _roles.map((String role) {
                final roleInfo = roleInfos[role]!;
                return DropdownMenuItem<String>(
                  value: role,
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: roleInfo.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(roleInfo.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedRole = newValue;
                });
              },
              validator: (value) {
                if (!_isNotReadyYet && (value == null || value.isEmpty)) {
                  return 'Please select a role';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final selectedTimezone = await showDialog<String>(
                  context: context,
                  builder: (context) => TimezonePickerDialog(
                    initialValue: _selectedTimezone,
                  ),
                );
                if (selectedTimezone != null) {
                  setState(() {
                    _selectedTimezone = selectedTimezone;
                  });
                }
              },
              child: Text(_selectedTimezone != null
                ? '${_selectedTimezone!} (${_formatTimezoneOffset(_selectedTimezone!)})'
                : 'Select Timezone'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Active Hours Start'),
                    subtitle: Text(_formatTimeOfDay(_startTime)),
                    onTap: () => _selectTime(context, true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('Active Hours End'),
                    subtitle: Text(_formatTimeOfDay(_endTime)),
                    onTap: () => _selectTime(context, false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Custom Fields',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addCustomField,
                          tooltip: 'Add Custom Field',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._customFieldControllers.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: entry.key,
                                decoration: const InputDecoration(
                                  labelText: 'Key',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: entry.value,
                                decoration: const InputDecoration(
                                  labelText: 'Value',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _removeCustomField(entry.key),
                              color: Colors.red,
                              tooltip: 'Remove Field',
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Not Ready Yet'),
              value: _isNotReadyYet,
              onChanged: (bool? value) {
                setState(() {
                  _isNotReadyYet = value ?? false;
                });
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  final newMember = TeamMember(
                    id: const Uuid().v4(),
                    name: _nameController.text,
                    email: _isNotReadyYet ? '' : _emailController.text, // Empty string if not ready
                    role: _isNotReadyYet ? '' : _selectedRole ?? '', // Empty string if not ready
                    timezone: _isNotReadyYet ? 'UTC' : _selectedTimezone ?? 'UTC', // Use UTC as default
                    activeHoursStart: _formatTimeOfDay(_startTime),
                    activeHoursEnd: _formatTimeOfDay(_endTime),
                    customFields: _getCustomFields(),
                  );

                  StorageService.instance.saveTeamMember(newMember);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save Member'),
            ),
          ],
        ),
      ),
    );
  }
}

class EditMemberPage extends StatefulWidget {
  final TeamMember member;

  const EditMemberPage({
    super.key,
    required this.member,
  });

  @override
  State<EditMemberPage> createState() => _EditMemberPageState();
}

class _EditMemberPageState extends State<EditMemberPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late String? _selectedRole;
  late String? _selectedTimezone;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  final Map<TextEditingController, TextEditingController> _customFieldControllers = {};
  bool _isNotReadyYet = false;

  final List<String> _roles = roleInfos.keys.toList();

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing member data
    _nameController = TextEditingController(text: widget.member.name);
    _emailController = TextEditingController(text: widget.member.email);

    // Check if role is empty or not in the available roles
    if (widget.member.role == null || widget.member.role!.isEmpty || !_roles.contains(widget.member.role)) {
      _selectedRole = null; // Set to null if role is empty or invalid
      _isNotReadyYet = true; // Set Not Ready Yet to true
    } else {
      _selectedRole = widget.member.role;
    }

    _selectedTimezone = widget.member.timezone ?? 'UTC';

    // Parse existing active hours
    final format = DateFormat('HH:mm');
    final startTime = format.parse(widget.member.activeHoursStart);
    final endTime = format.parse(widget.member.activeHoursEnd);
    _startTime = TimeOfDay(hour: startTime.hour, minute: startTime.minute);
    _endTime = TimeOfDay(hour: endTime.hour, minute: endTime.minute);

    // Initialize custom field controllers
    widget.member.customFields.forEach((key, value) {
      _customFieldControllers[TextEditingController(text: key)] =
          TextEditingController(text: value);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    for (var controllers in _customFieldControllers.entries) {
      controllers.key.dispose();
      controllers.value.dispose();
    }
    super.dispose();
  }

  void _addCustomField() {
    setState(() {
      _customFieldControllers[TextEditingController()] = TextEditingController();
    });
  }

  void _removeCustomField(TextEditingController keyController) {
    setState(() {
      final valueController = _customFieldControllers.remove(keyController);
      keyController.dispose();
      valueController?.dispose();
    });
  }

  Map<String, String> _getCustomFields() {
    final customFields = <String, String>{};
    for (var entry in _customFieldControllers.entries) {
      final key = entry.key.text.trim();
      final value = entry.value.text.trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        customFields[key] = value;
      }
    }
    return customFields;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimezoneOffset(String timezone) {
    final location = tz.getLocation(timezone);
    final offsetInSeconds = location.currentTimeZone.offset ~/ 1000;
    final absSeconds = offsetInSeconds.abs();
    final hours = absSeconds ~/ 3600;
    final minutes = (absSeconds % 3600) ~/ 60;

    final sign = offsetInSeconds >= 0 ? '+' : '-';
    return 'GMT$sign${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Team Member'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (!_isNotReadyYet && (value == null || value.isEmpty)) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (!_isNotReadyYet && (value == null || value.isEmpty)) {
                  return 'Please enter an email';
                }
                if (value != null && !value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              items: _roles.map((String role) {
                final roleInfo = roleInfos[role]!;
                return DropdownMenuItem<String>(
                  value: role,
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: roleInfo.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(roleInfo.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedRole = newValue;
                });
              },
              validator: (value) {
                if (!_isNotReadyYet && (value == null || value.isEmpty)) {
                  return 'Please select a role';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final selectedTimezone = await showDialog<String>(
                  context: context,
                  builder: (context) => TimezonePickerDialog(
                    initialValue: _selectedTimezone,
                  ),
                );
                if (selectedTimezone != null) {
                  setState(() {
                    _selectedTimezone = selectedTimezone;
                  });
                }
              },
              child: Text(_selectedTimezone != null
                ? '${_selectedTimezone!} (${_formatTimezoneOffset(_selectedTimezone!)})'
                : 'Select Timezone'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Active Hours Start'),
                    subtitle: Text(_formatTimeOfDay(_startTime)),
                    onTap: () => _selectTime(context, true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('Active Hours End'),
                    subtitle: Text(_formatTimeOfDay(_endTime)),
                    onTap: () => _selectTime(context, false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Custom Fields',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addCustomField,
                          tooltip: 'Add Custom Field',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._customFieldControllers.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: entry.key,
                                decoration: const InputDecoration(
                                  labelText: 'Key',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: entry.value,
                                decoration: const InputDecoration(
                                  labelText: 'Value',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _removeCustomField(entry.key),
                              color: Colors.red,
                              tooltip: 'Remove Field',
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Not Ready Yet'),
              value: _isNotReadyYet,
              onChanged: (bool? value) {
                setState(() {
                  _isNotReadyYet = value ?? false;
                });
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final updatedMember = TeamMember(
                    id: widget.member.id,
                    name: _nameController.text,
                    email: _isNotReadyYet ? '' : _emailController.text, // Email is optional if not ready
                    role: _isNotReadyYet ? '' : _selectedRole ?? '', // Role is optional if not ready
                    timezone: _isNotReadyYet ? 'UTC' : _selectedTimezone ?? 'UTC', // Use UTC as default
                    activeHoursStart: _formatTimeOfDay(_startTime),
                    activeHoursEnd: _formatTimeOfDay(_endTime),
                    customFields: _getCustomFields(),
                  );

                  await StorageService.instance.updateMember(updatedMember);
                  if (mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TimezonePickerDialog extends StatefulWidget {
  final String? initialValue;

  const TimezonePickerDialog({
    super.key,
    this.initialValue,
  });

  @override
  State<TimezonePickerDialog> createState() => _TimezonePickerDialogState();
}

class _TimezonePickerDialogState extends State<TimezonePickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<String> _timezones = [];
  List<String> _filteredTimezones = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _timezones = tz.timeZoneDatabase.locations.keys.toList()..sort();
    _filteredTimezones = _timezones;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (_searchController.text == _searchQuery) return;

      setState(() {
        _searchQuery = _searchController.text;
        if (_searchQuery.isEmpty) {
          _filteredTimezones = _timezones;
        } else {
          _filteredTimezones = _timezones
              .where((tz) =>
                  tz.toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList();
        }
      });
    });
  }

  String _formatTimezoneOffset(String timezone) {
    final location = tz.getLocation(timezone);
    final offsetInSeconds = location.currentTimeZone.offset ~/ 1000;
    final absSeconds = offsetInSeconds.abs();
    final hours = absSeconds ~/ 3600;
    final minutes = (absSeconds % 3600) ~/ 60;

    final sign = offsetInSeconds >= 0 ? '+' : '-';
    return 'GMT$sign${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 500,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search Timezone',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _filteredTimezones = _timezones;
                          });
                        },
                      )
                    : null,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredTimezones.length,
                  itemBuilder: (context, index) {
                    final timezone = _filteredTimezones[index];
                    final isSelected = timezone == widget.initialValue;

                    return ListTile(
                      title: Text(timezone),
                      subtitle: Text(_formatTimezoneOffset(timezone)),
                      selected: isSelected,
                      tileColor: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                      onTap: () => Navigator.of(context).pop(timezone),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MemberDetailPage extends StatelessWidget {
  final TeamMember member;

  const MemberDetailPage({
    super.key,
    required this.member,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(member.name ?? 'Unnamed'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${member.name ?? 'Unnamed'}'),
            const SizedBox(height: 8),
            Text('Email: ${member.email ?? 'Not provided'}'),
            const SizedBox(height: 8),
            Text('Role: ${member.role ?? 'Not specified'}'),
            const SizedBox(height: 8),
            Text(
              'Timezone: ${member.timezone ?? 'Not specified'} (${_formatTimezoneOffset(member.timezone ?? 'UTC')})',
            ),
            const SizedBox(height: 8),
            Text(
              'Active Hours: ${member.activeHoursStart} - ${member.activeHoursEnd}',
            ),
            if (member.customFields.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Custom Fields:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ...member.customFields.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.key}:',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Text(entry.value),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: entry.value));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copied to clipboard!'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimezoneOffset(String timezone) {
    final location = tz.getLocation(timezone);
    final offsetInSeconds = location.currentTimeZone.offset ~/ 1000;
    final absSeconds = offsetInSeconds.abs();
    final hours = absSeconds ~/ 3600;
    final minutes = (absSeconds % 3600) ~/ 60;

    final sign = offsetInSeconds >= 0 ? '+' : '-';
    return 'GMT$sign${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }
}
