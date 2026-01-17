class User {
  const User({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
    this.court,
    this.contactInfo,
    this.district,
    this.province,
    this.region,
    this.dateCreated,
  });

  final String id;
  final String name;
  final String role;
  final String email;
  final String? court;
  final String? contactInfo;
  final String? district;
  final String? province;
  final String? region;
  final String? dateCreated;

  User copyWith({
    String? id,
    String? name,
    String? role,
    String? email,
    String? court,
    String? contactInfo,
    String? district,
    String? province,
    String? region,
    String? dateCreated,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      email: email ?? this.email,
      court: court ?? this.court,
      contactInfo: contactInfo ?? this.contactInfo,
      district: district ?? this.district,
      province: province ?? this.province,
      region: region ?? this.region,
      dateCreated: dateCreated ?? this.dateCreated,
    );
  }
}
