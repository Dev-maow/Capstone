// lib/models/auth_models.dart

enum UserRole { admin, staff }

class AppUser {
  final String id;
  final String username;
  final String password; // In production, store hashed
  final String displayName;
  final UserRole role;
  final String avatarInitials;

  const AppUser({
    required this.id,
    required this.username,
    required this.password,
    required this.displayName,
    required this.role,
    required this.avatarInitials,
  });

  bool get isAdmin => role == UserRole.admin;

  String get roleLabel => role == UserRole.admin ? 'Admin' : 'Staff';
}

// ── Hardcoded credentials (in production use a backend/hashed DB) ──
const List<AppUser> kAppUsers = [
  AppUser(
    id: 'u1',
    username: 'admin',
    password: 'admin123',
    displayName: 'Dr. Reyes',
    role: UserRole.admin,
    avatarInitials: 'DR',
  ),
  AppUser(
    id: 'u2',
    username: 'staff1',
    password: 'staff123',
    displayName: 'Nurse Santos',
    role: UserRole.staff,
    avatarInitials: 'NS',
  ),
  AppUser(
    id: 'u3',
    username: 'staff2',
    password: 'staff456',
    displayName: 'Asst. Dela Cruz',
    role: UserRole.staff,
    avatarInitials: 'AD',
  ),
];
