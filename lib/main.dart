import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'utils/theme.dart';
import 'utils/app_data.dart';
import 'utils/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/ar_screen.dart';
import 'screens/patients_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/ai_assistant_screen.dart';
import 'models/auth_models.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF0D47A1),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppData()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const DentaLogicApp(),
    ),
  );
}

class DentaLogicApp extends StatelessWidget {
  const DentaLogicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    return MaterialApp(
      title: 'DentaLogic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: data.themeMode,
      home: const AppBootstrapGate(),
    );
  }
}

class AppBootstrapGate extends StatefulWidget {
  const AppBootstrapGate({super.key});

  @override
  State<AppBootstrapGate> createState() => _AppBootstrapGateState();
}

class _AppBootstrapGateState extends State<AppBootstrapGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1700), () {
      if (mounted) {
        setState(() => _ready = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _ready ? const AuthGate() : const _StartupScreen(),
    );
  }
}

class _StartupScreen extends StatefulWidget {
  const _StartupScreen();

  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF07111D),
              Color(0xFF0F3FA7),
              Color(0xFF2A8CFF),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned(
              top: -80,
              right: -30,
              child: _AmbientOrb(size: 240, color: Colors.white24),
            ),
            const Positioned(
              bottom: -60,
              left: -10,
              child: _AmbientOrb(size: 220, color: Color(0x268ED8FF)),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) => Transform.scale(
                      scale: 0.96 + (_controller.value * 0.08),
                      child: Container(
                        width: 102,
                        height: 102,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.92),
                              Colors.white.withOpacity(0.68),
                            ],
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.9)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.16),
                              blurRadius: 28,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'DL',
                            style: GoogleFonts.dmSans(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF11347A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'DentaLogic',
                    style: GoogleFonts.dmSans(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Clinical AR and practice workflow',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.74),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: Colors.white.withOpacity(0.92),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _AmbientOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 40,
            spreadRadius: 14,
          ),
        ],
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return auth.isLoggedIn ? const MainShell() : const LoginScreen();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    ArScreen(),
    PatientsScreen(),
    _MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser!;

    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.appBackground),
        child: Column(
          children: [
            if (!auth.isAdmin)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF16253A), Color(0xFF0F1828)],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.badge_rounded, size: 14, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      '${user.displayName} • Staff access',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: IndexedStack(index: _currentIndex, children: _screens),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        alertCount: data.totalAlerts,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final int alertCount;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.alertCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.auto_fix_high_outlined, activeIcon: Icons.auto_fix_high_rounded, label: 'AR Smile'),
      _NavItem(icon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded, label: 'Patients'),
      _NavItem(icon: Icons.grid_view_rounded, activeIcon: Icons.grid_view_rounded, label: 'More', badge: alertCount),
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF0F1B2D) : Colors.white).withOpacity(0.78),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: (isDark ? Colors.white : Colors.white).withOpacity(0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.30 : 0.12),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isActive = currentIndex == index;

            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? const LinearGradient(
                            colors: [Color(0xFFE9F3FF), Color(0xFFDCEBFF)],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            isActive ? item.activeIcon : item.icon,
                            size: 22,
                            color: isActive
                                ? AppTheme.primary
                                : (isDark ? const Color(0xFFA8B3C7) : const Color(0xFF77839A)),
                          ),
                          if (item.badge != null && item.badge! > 0)
                            Positioned(
                              top: -3,
                              right: -8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF7A4D),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  item.badge! > 9 ? '9+' : '${item.badge}',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.label,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive
                              ? AppTheme.primary
                              : (isDark ? const Color(0xFFA8B3C7) : const Color(0xFF77839A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? badge;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge,
  });
}

class _MoreScreen extends StatelessWidget {
  const _MoreScreen();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser!;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.appBackground),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF07111D), Color(0xFF133A89), Color(0xFF1A64F0)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF143C93).withOpacity(0.24),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.16),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.18)),
                          ),
                          child: Center(
                            child: Text(
                              user.avatarInitials,
                              style: GoogleFonts.dmSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName,
                                style: GoogleFonts.dmSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '@${user.username} • ${user.roleLabel}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.72),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            user.roleLabel,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Everything outside the main workflow lives here: assistant, inventory, alerts, and account controls.',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.white.withOpacity(0.78),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _SectionLabel(label: 'CLINIC TOOLS'),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [
                  _MoreTile(
                    icon: Icons.smart_toy_outlined,
                    label: 'AI Assistant',
                    subtitle: 'Smart reminders and help',
                    color: const Color(0xFF6A5CFF),
                    accent: const Color(0xFFEDEBFF),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
                    ),
                  ),
                  _MoreTile(
                    icon: Icons.inventory_2_outlined,
                    label: 'Inventory',
                    subtitle: '${data.inventory.length} items tracked',
                    color: const Color(0xFF2F7A47),
                    accent: const Color(0xFFEAF7EF),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const InventoryScreen()),
                    ),
                  ),
                  _MoreTile(
                    icon: Icons.notifications_none_rounded,
                    label: 'Alerts',
                    subtitle: '${data.totalAlerts} clinic alerts',
                    color: data.totalAlerts > 0 ? AppTheme.warning : AppTheme.success,
                    accent: data.totalAlerts > 0
                        ? const Color(0xFFFFF4DD)
                        : const Color(0xFFE7FAF1),
                    badge: data.totalAlerts,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AlertsScreen()),
                    ),
                  ),
                  _MoreTile(
                    icon: Icons.insights_outlined,
                    label: 'Reports',
                    subtitle: 'Usage and clinic trends',
                    color: const Color(0xFF475569),
                    accent: const Color(0xFFF1F5F9),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reports are coming in a future update.')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SectionLabel(label: 'ACCOUNT'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassCard(radius: BorderRadius.circular(22)),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.dark_mode_outlined, size: 20, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Appearance', style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                          const SizedBox(height: 3),
                          Text(
                            data.themeMode == ThemeMode.dark ? 'Dark mode' : 'Light mode',
                            style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: data.themeMode == ThemeMode.dark,
                      onChanged: (_) => data.toggleThemeMode(),
                      activeColor: AppTheme.secondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _MoreInfoTile(
                icon: Icons.verified_user_outlined,
                label: 'Access level',
                value: user.roleLabel,
                accent: user.isAdmin ? const Color(0xFFFFF4DD) : const Color(0xFFE8F0FF),
                color: user.isAdmin ? const Color(0xFFC28500) : AppTheme.primary,
              ),
              const SizedBox(height: 10),
              _MoreInfoTile(
                icon: Icons.alternate_email_rounded,
                label: 'Username',
                value: '@${user.username}',
                accent: const Color(0xFFF1F5F9),
                color: const Color(0xFF64748B),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context, auth),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: BorderSide(color: AppTheme.error.withOpacity(0.28)),
                    backgroundColor: Colors.white.withOpacity(0.70),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Sign out',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to sign out of DentaLogic?',
          style: GoogleFonts.dmSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              auth.logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.onSurfaceVariant,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color accent;
  final int? badge;
  final VoidCallback? onTap;

  const _MoreTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.accent,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassCard(radius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                if (badge != null && badge! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEEE8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge! > 9 ? '9+' : '$badge',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE1633C),
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color color;

  const _MoreInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(radius: BorderRadius.circular(22)),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  final AppUser user;
  final AuthProvider auth;

  const _ProfilePage({required this.user, required this.auth});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.glassCard(radius: BorderRadius.circular(26)),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: user.isAdmin ? AppTheme.primaryContainer : const Color(0xFFECEFF1),
                  child: Text(
                    user.avatarInitials,
                    style: GoogleFonts.dmSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: user.isAdmin ? AppTheme.onPrimaryContainer : const Color(0xFF37474F),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  user.displayName,
                  style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '@${user.username}',
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                auth.logout();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
