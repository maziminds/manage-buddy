class TeamMember {
  final String id;
  final String name;
  final String? email;
  final String? role;
  final String? timezone;
  final String activeHoursStart;
  final String activeHoursEnd;
  final Map<String, String> customFields;

  TeamMember({
    required this.id,
    required this.name,
    this.email,
    this.role,
    this.timezone,
    required this.activeHoursStart,
    required this.activeHoursEnd,
    Map<String, String>? customFields,
  }) : customFields = customFields ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'timezone': timezone,
        'activeHoursStart': activeHoursStart,
        'activeHoursEnd': activeHoursEnd,
        'customFields': customFields,
      };

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String?,
        role: json['role'] as String?,
        timezone: json['timezone'] as String?,
        activeHoursStart: json['activeHoursStart'] as String,
        activeHoursEnd: json['activeHoursEnd'] as String,
        customFields: (json['customFields'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value.toString()),
        ) ?? {},
      );
}
