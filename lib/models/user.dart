/// Miroir de `UserSerializer` (backend/application/serializers/auth.py).
enum UserRole { admin, enseignant, etudiant, responsable, secretariat, parent, gardien, inconnu }

UserRole roleFromString(String? value) {
  switch (value) {
    case 'ADMIN':
      return UserRole.admin;
    case 'ENSEIGNANT':
      return UserRole.enseignant;
    case 'ETUDIANT':
      return UserRole.etudiant;
    case 'RESPONSABLE':
      return UserRole.responsable;
    case 'SECRETARIAT':
      return UserRole.secretariat;
    case 'PARENT':
      return UserRole.parent;
    case 'GARDIEN':
      return UserRole.gardien;
    default:
      return UserRole.inconnu;
  }
}

class AppUser {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final UserRole role;
  final String? matricule;
  final String? telephone;
  final String? photo;
  final int? ecoleId;
  final bool mustChangePassword;

  AppUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.matricule,
    this.telephone,
    this.photo,
    this.ecoleId,
    this.mustChangePassword = false,
  });

  /// Rôles "personnel" habilités à publier des annonces / composer des messages
  /// (mêmes STAFF_ROLES que côté web, cf. AnnoncesPanel.jsx / MessageriePanel.jsx).
  bool get estPersonnel => {UserRole.admin, UserRole.responsable, UserRole.enseignant, UserRole.secretariat}.contains(role);

  String get fullName => '$firstName $lastName'.trim();
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final result = '$f$l'.toUpperCase();
    return result.isEmpty ? '?' : result;
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      role: roleFromString(json['role'] as String?),
      matricule: json['matricule'] as String?,
      telephone: json['telephone'] as String?,
      photo: json['photo'] as String?,
      ecoleId: json['ecole'] as int?,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
    );
  }
}
