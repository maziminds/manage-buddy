import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/team_member.dart';

class MemberDetailPage extends StatelessWidget {
  final TeamMember member;

  const MemberDetailPage({Key? key, required this.member}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(member.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Email: ${member.email}'),
                    const SizedBox(height: 8),
                    Text(
                      'Timezone: ${member.timezone ?? 'UTC'} (${_formatTimezoneOffset(member.timezone ?? 'UTC')})',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Active Hours: ${member.activeHoursStart} - ${member.activeHoursEnd}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Custom Fields:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ...member.customFields.entries.map((entry) {
                      print('No scheme: ${entry.value}');
                      if (Uri.tryParse(entry.value)?.hasScheme ?? false) {
                        print('Has scheme: ${entry.value}');
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () {
                                launch(entry.value);
                              },
                              child: Text(
                                'Open Link',
                                style: TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.copy),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: entry.value));
                                print('Copied to clipboard: ${entry.value}');
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied to clipboard!')));
                              },
                            ),
                          ],
                        );
                      } else {

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${entry.key}: ${entry.value}'),
                            IconButton(
                              icon: Icon(Icons.copy),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: entry.value));
                                print('Copied to clipboard: ${entry.value}');
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied to clipboard!')));
                              },
                            ),
                          ],
                        );
                      }
                    }).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimezoneOffset(String timezone) {
    // implement your timezone offset formatting logic here
    return '';
  }
}
