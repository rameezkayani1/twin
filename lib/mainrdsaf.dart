// ============================================================================
// TWINS HANDYMAN LLC — Mobile App UI Sample
// ----------------------------------------------------------------------------
// UI-ONLY DEMO BUILD — all data below is mock/demo data. No backend, no auth,
// no payment processing is actually wired up. Built to show layout, flow and
// visual direction for client review before development begins.
//
// To run: create a new Flutter project (`flutter create twins_handyman`),
// replace lib/main.dart with this file, then `flutter run`.
// No extra packages required — uses only the Flutter SDK.
// ============================================================================

import 'package:flutter/material.dart';

void main() {
  runApp(const TwinsApp());
}

// ============================================================================
// DESIGN TOKENS
// ============================================================================
class AppColors {
  static const ink = Color(
    0xFF1B1F24,
  ); // near-black charcoal — text, dark surfaces
  static const inkSoft = Color(0xFF4A5158); // secondary text
  static const bg = Color(0xFFF5F4F1); // warm neutral background
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFE3E1DC); // hairline dividers
  static const primary = Color(0xFFFF6A13); // safety orange — primary action
  static const primaryDark = Color(0xFFD9560C);
  static const secondary = Color(
    0xFF2D5F7C,
  ); // steel blue — headers, secondary UI
  static const secondaryDark = Color(0xFF1E4356);
  static const success = Color(0xFF2E7D57);
  static const successBg = Color(0xFFE4F2EA);
  static const warning = Color(0xFFB9791B);
  static const warningBg = Color(0xFFFBF0DD);
  static const danger = Color(0xFFC7402E);
  static const dangerBg = Color(0xFFFBE7E3);
  static const infoBg = Color(0xFFE7EEF2);
}

const _stages = [
  'Request received',
  'Quote sent',
  'Scheduled',
  'In progress',
  'Completed',
];

// ============================================================================
// MOCK DATA MODELS
// ============================================================================
class ServiceItem {
  final String name;
  final IconData icon;
  const ServiceItem(this.name, this.icon);
}

const List<ServiceItem> kServices = [
  ServiceItem('Painting', Icons.format_paint_outlined),
  ServiceItem('Moving', Icons.local_shipping_outlined),
  ServiceItem('Cleaning', Icons.cleaning_services_outlined),
  ServiceItem('Assembly', Icons.build_outlined),
  ServiceItem('Lawn Services', Icons.grass_outlined),
  ServiceItem('Waste Disposal', Icons.delete_outline),
  ServiceItem('Pressure Washing', Icons.water_drop_outlined),
  ServiceItem('General Handyman', Icons.handyman_outlined),
];

class QuoteLine {
  final String label;
  final double amount;
  const QuoteLine(this.label, this.amount);
}

class QuoteItem {
  final String id;
  final String service;
  final String dateIssued;
  final String address;
  String status; // Pending, Sent, Accepted, Rejected
  final List<QuoteLine> lines;
  final String notes;
  QuoteItem({
    required this.id,
    required this.service,
    required this.dateIssued,
    required this.address,
    required this.status,
    required this.lines,
    required this.notes,
  });
  double get total => lines.fold(0, (sum, l) => sum + l.amount);
}

final List<QuoteItem> kQuotes = [
  QuoteItem(
    id: 'Q-1042',
    service: 'Pressure Washing',
    dateIssued: 'Sep 18, 2026',
    address: '214 Maple Street, Rawalpindi',
    status: 'Sent',
    lines: const [
      QuoteLine('Driveway + walkway wash', 90),
      QuoteLine('Deck restoration', 60),
    ],
    notes: 'Quote valid for 14 days. 50% deposit required to schedule.',
  ),
  QuoteItem(
    id: 'Q-1039',
    service: 'Painting',
    dateIssued: 'Sep 12, 2026',
    address: '77 Birchwood Ave, Rawalpindi',
    status: 'Accepted',
    lines: const [
      QuoteLine('Living room (2 coats)', 220),
      QuoteLine('Hallway trim', 75),
      QuoteLine('Paint + materials', 85),
    ],
    notes: 'Client supplied color: Sherwin-Williams "Agreeable Gray".',
  ),
  QuoteItem(
    id: 'Q-1031',
    service: 'General Handyman',
    dateIssued: 'Aug 30, 2026',
    address: '9 Cedar Court, Rawalpindi',
    status: 'Rejected',
    lines: const [
      QuoteLine('Cabinet door realignment', 45),
      QuoteLine('Leaky faucet repair', 65),
    ],
    notes: 'Customer opted to reschedule for a later date.',
  ),
];

class JobItem {
  final String id;
  final String service;
  final String address;
  final String date;
  final String time;
  int stage; // index into _stages
  final String quoteId;
  JobItem({
    required this.id,
    required this.service,
    required this.address,
    required this.date,
    required this.time,
    required this.stage,
    required this.quoteId,
  });
}

final List<JobItem> kJobs = [
  JobItem(
    id: 'J-2201',
    service: 'Painting',
    address: '77 Birchwood Ave, Rawalpindi',
    date: 'Sep 24, 2026',
    time: '9:00 AM',
    stage: 2,
    quoteId: 'Q-1039',
  ),
  JobItem(
    id: 'J-2188',
    service: 'Lawn Services',
    address: '214 Maple Street, Rawalpindi',
    date: 'Sep 10, 2026',
    time: '2:00 PM',
    stage: 4,
    quoteId: 'Q-1020',
  ),
  JobItem(
    id: 'J-2175',
    service: 'Assembly',
    address: '9 Cedar Court, Rawalpindi',
    date: 'Aug 29, 2026',
    time: '11:00 AM',
    stage: 4,
    quoteId: 'Q-1015',
  ),
];

class InvoiceItem {
  final String id;
  final String job;
  final double amount;
  final String date;
  String status; // Due, Paid, Deposit paid
  InvoiceItem({
    required this.id,
    required this.job,
    required this.amount,
    required this.date,
    required this.status,
  });
}

final List<InvoiceItem> kInvoices = [
  InvoiceItem(
    id: 'INV-3390',
    job: 'Painting — Living room & hallway',
    amount: 380,
    date: 'Sep 24, 2026',
    status: 'Due',
  ),
  InvoiceItem(
    id: 'INV-3376',
    job: 'Lawn Services — Biweekly mow',
    amount: 65,
    date: 'Sep 10, 2026',
    status: 'Paid',
  ),
  InvoiceItem(
    id: 'INV-3358',
    job: 'Furniture Assembly — Bedroom set',
    amount: 110,
    date: 'Aug 29, 2026',
    status: 'Paid',
  ),
];

class ChatMessage {
  final bool fromMe;
  final String text;
  final String time;
  const ChatMessage(this.fromMe, this.text, this.time);
}

final List<ChatMessage> kMessages = [
  const ChatMessage(
    false,
    "Hi! This is Twins Handyman. We got your request for pressure washing — we'll send a quote shortly.",
    '9:02 AM',
  ),
  const ChatMessage(true, 'Sounds good, thank you!', '9:05 AM'),
  const ChatMessage(
    false,
    'Quote Q-1042 has been sent to your account for review.',
    '11:20 AM',
  ),
];

const List<String> kSavedAddresses = [
  '214 Maple Street, Rawalpindi',
  '77 Birchwood Ave, Rawalpindi',
  '9 Cedar Court, Rawalpindi',
];

// ============================================================================
// APP ROOT
// ============================================================================
class TwinsApp extends StatelessWidget {
  const TwinsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Twins Handyman',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const LoginScreen(),
    );
  }

  ThemeData _buildTheme() {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        bodyLarge: TextStyle(color: AppColors.ink, height: 1.4),
        bodyMedium: TextStyle(color: AppColors.inkSoft, height: 1.4),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: AppColors.ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        labelStyle: const TextStyle(color: AppColors.inkSoft),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    );
  }
}

// ============================================================================
// SHARED WIDGETS
// ============================================================================
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  const StatusChip(this.label, {super.key});

  _StatusStyle _styleFor(String s) {
    switch (s) {
      case 'Accepted':
      case 'Paid':
      case 'Completed':
        return _StatusStyle(AppColors.success, AppColors.successBg);
      case 'Rejected':
        return _StatusStyle(AppColors.danger, AppColors.dangerBg);
      case 'Pending':
      case 'Due':
      case 'Request received':
        return _StatusStyle(AppColors.warning, AppColors.warningBg);
      default:
        return _StatusStyle(AppColors.secondary, AppColors.infoBg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _styleFor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: s.fg,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StatusStyle {
  final Color fg;
  final Color bg;
  _StatusStyle(this.fg, this.bg);
}

class TwinsLogo extends StatelessWidget {
  final double size;
  const TwinsLogo({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Center(
        child: Text(
          'TH',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.4,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

class PrimaryCta extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const PrimaryCta({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(onPressed: onTap, child: Text(label)),
    );
  }
}

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

// ============================================================================
// LOGIN / SIGN UP
// ============================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isSignUp = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                Row(
                  children: const [
                    TwinsLogo(size: 52),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Twins Handyman',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 46),
                Text(
                  isSignUp ? 'Create your account' : 'Welcome back',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 30,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isSignUp
                      ? 'Book services, track jobs, and manage payments in one place.'
                      : 'Sign in to manage your service requests.',
                  style: const TextStyle(
                    color: Color(0xFFB9BFC6),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      if (isSignUp) ...[
                        const _DemoField(
                          label: 'Full name',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 12),
                      ],
                      const _DemoField(
                        label: 'Email address',
                        icon: Icons.mail_outline,
                      ),
                      const SizedBox(height: 12),
                      if (isSignUp) ...[
                        const _DemoField(
                          label: 'Phone number',
                          icon: Icons.call_outlined,
                        ),
                        const SizedBox(height: 12),
                      ],
                      const _DemoField(
                        label: 'Password',
                        icon: Icons.lock_outline,
                        obscure: true,
                      ),
                      const SizedBox(height: 20),
                      PrimaryCta(
                        label: isSignUp ? 'Create account' : 'Log in',
                        onTap: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const RootShell(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      if (!isSignUp)
                        TextButton(
                          onPressed: () => _snack(
                            context,
                            'Password reset link sent (demo)',
                          ),
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(color: AppColors.inkSoft),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => isSignUp = !isSignUp),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: Color(0xFFB9BFC6),
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: isSignUp
                                ? 'Already have an account? '
                                : "Don't have an account? ",
                          ),
                          TextSpan(
                            text: isSignUp ? 'Log in' : 'Sign up',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoField extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool obscure;
  const _DemoField({
    required this.label,
    required this.icon,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.inkSoft),
      ),
    );
  }
}

// ============================================================================
// ROOT SHELL — bottom navigation
// ============================================================================
class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int index = 0;

  final tabs = const [
    _HomeTab(),
    RequestServiceScreen(embedded: true),
    QuotesTab(),
    JobsTab(),
    AccountTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: index, children: tabs),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primary.withOpacity(0.12),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.inkSoft,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => setState(() => index = i),
          height: 66,
          destinations: [
            _navDest(Icons.home_outlined, Icons.home, 'Home', 0),
            _navDest(Icons.add_circle_outline, Icons.add_circle, 'Request', 1),
            _navDest(
              Icons.receipt_long_outlined,
              Icons.receipt_long,
              'Quotes',
              2,
            ),
            _navDest(Icons.event_note_outlined, Icons.event_note, 'Jobs', 3),
            _navDest(Icons.person_outline, Icons.person, 'Account', 4),
          ],
        ),
      ),
    );
  }

  NavigationDestination _navDest(
    IconData outline,
    IconData filled,
    String label,
    int i,
  ) {
    return NavigationDestination(
      icon: Icon(outline, color: AppColors.inkSoft),
      selectedIcon: Icon(filled, color: AppColors.primary),
      label: label,
    );
  }
}

// ============================================================================
// HOME TAB
// ============================================================================
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final nextJob = kJobs.first;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Good morning, Sarah',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'What do you need done?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                Stack(
                  children: [
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.ink,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MessagesScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.notifications_outlined),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Hero: next appointment
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Next appointment',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    nextJob.service,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Color(0xFFB9BFC6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${nextJob.date} · ${nextJob.time}',
                        style: const TextStyle(
                          color: Color(0xFFB9BFC6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Color(0xFFB9BFC6),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          nextJob.address,
                          style: const TextStyle(
                            color: Color(0xFFB9BFC6),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF3A414A)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => JobDetailScreen(job: nextJob),
                            ),
                          ),
                          child: const Text('View details'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showReschedule(context),
                          child: const Text('Reschedule'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Quick actions
          const SectionHeader(title: 'Quick actions'),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 10,
              children: [
                _QuickAction(
                  icon: Icons.add_circle_outline,
                  label: 'Request',
                  onTap: () => _goTab(context, 1),
                ),
                _QuickAction(
                  icon: Icons.receipt_long_outlined,
                  label: 'Quotes',
                  onTap: () => _goTab(context, 2),
                ),
                _QuickAction(
                  icon: Icons.payments_outlined,
                  label: 'Payments',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaymentsScreen()),
                  ),
                ),
                _QuickAction(
                  icon: Icons.chat_bubble_outline,
                  label: 'Message',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MessagesScreen()),
                  ),
                ),
              ],
            ),
          ),

          const SectionHeader(title: 'Our services', action: 'See all'),
          SizedBox(
            height: 108,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: kServices.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _ServiceChipCard(service: kServices[i]),
            ),
          ),

          const SectionHeader(title: 'Recent activity'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _ActivityRow(
                  icon: Icons.receipt_long_outlined,
                  title: 'Quote Q-1042 sent',
                  subtitle: 'Pressure Washing · \$150.00',
                  time: '2h ago',
                ),
                _ActivityRow(
                  icon: Icons.check_circle_outline,
                  title: 'Job J-2188 completed',
                  subtitle: 'Lawn Services',
                  time: 'Sep 10',
                ),
                _ActivityRow(
                  icon: Icons.payment_outlined,
                  title: 'Payment received',
                  subtitle: 'INV-3376 · \$65.00',
                  time: 'Sep 10',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _goTab(BuildContext context, int i) {
    final state = context.findAncestorStateOfType<_RootShellState>();
    state?.setState(() => state.index = i);
  }
}

void _showReschedule(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _RescheduleSheet(),
  );
}

class _RescheduleSheet extends StatefulWidget {
  const _RescheduleSheet();
  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  int selectedDay = 2;
  String selectedTime = '9:00 AM';
  final days = const ['Mon 22', 'Tue 23', 'Wed 24', 'Thu 25', 'Fri 26'];
  final times = const ['9:00 AM', '11:00 AM', '1:00 PM', '3:00 PM'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Reschedule appointment',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          const Text(
            'Pick a new day',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final sel = i == selectedDay;
                return GestureDetector(
                  onTap: () => setState(() => selectedDay = i),
                  child: Container(
                    width: 62,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? AppColors.ink : AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      days[i],
                      style: TextStyle(
                        color: sel ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pick a time',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: times.map((t) {
              final sel = t == selectedTime;
              return GestureDetector(
                onTap: () => setState(() => selectedTime = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    t,
                    style: TextStyle(
                      color: sel ? Colors.white : AppColors.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          PrimaryCta(
            label: 'Confirm new time',
            onTap: () {
              Navigator.pop(context);
              _snack(
                context,
                'Appointment moved to ${days[selectedDay]}, $selectedTime',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceChipCard extends StatelessWidget {
  final ServiceItem service;
  const _ServiceChipCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RequestServiceScreen(preselected: service.name),
        ),
      ),
      child: Container(
        width: 96,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(service.icon, color: AppColors.secondary, size: 22),
            const Spacer(),
            Text(
              service.name,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  const _ActivityRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// REQUEST SERVICE FLOW
// ============================================================================
class RequestServiceScreen extends StatefulWidget {
  final bool embedded;
  final String? preselected;
  const RequestServiceScreen({
    super.key,
    this.embedded = false,
    this.preselected,
  });

  @override
  State<RequestServiceScreen> createState() => _RequestServiceScreenState();
}

class _RequestServiceScreenState extends State<RequestServiceScreen> {
  int step = 0;
  String? selectedService;
  final descController = TextEditingController();
  int photoCount = 0;
  String address = kSavedAddresses.first;
  String date = 'Sep 26, 2026';
  String time = '10:00 AM';
  bool submitted = false;

  @override
  void initState() {
    super.initState();
    selectedService = widget.preselected;
    if (widget.preselected != null) step = 1;
  }

  void _next() {
    if (step == 0 && selectedService == null) {
      _snack(context, 'Please select a service to continue');
      return;
    }
    if (step < 3) {
      setState(() => step++);
    } else {
      setState(() => submitted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = submitted
        ? _buildConfirmation(context)
        : _buildStep(context);

    if (widget.embedded) {
      return SafeArea(child: content);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Request a service')),
      body: content,
    );
  }

  Widget _buildStep(BuildContext context) {
    return Column(
      children: [
        if (!widget.embedded)
          const SizedBox.shrink()
        else
          _EmbeddedHeader(step: step),
        _StepProgress(step: step),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              if (step == 0) _stepService(),
              if (step == 1) _stepDetails(),
              if (step == 2) _stepSchedule(),
              if (step == 3) _stepReview(),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(
            color: AppColors.bg,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              if (step > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: OutlinedButton(
                    onPressed: () => setState(() => step--),
                    child: const Icon(Icons.arrow_back, size: 18),
                  ),
                ),
              Expanded(
                child: PrimaryCta(
                  label: step == 3 ? 'Submit request' : 'Continue',
                  onTap: _next,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepService() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What do you need help with?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: kServices.map((s) {
            final sel = s.name == selectedService;
            return GestureDetector(
              onTap: () => setState(() => selectedService = s.name),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sel ? AppColors.ink : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: sel ? AppColors.ink : AppColors.line,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      s.icon,
                      color: sel ? AppColors.primary : AppColors.secondary,
                      size: 22,
                    ),
                    const Spacer(),
                    Text(
                      s.name,
                      style: TextStyle(
                        color: sel ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _stepDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Describe the job',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(
          'Selected service: $selectedService',
          style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: descController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText:
                'e.g. Repaint the living room and hallway, two coats, walls only...',
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Photos or videos',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 4),
        const Text(
          'Add up to 6 files to help us scope the job accurately.',
          style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (int i = 0; i < photoCount; i++) _photoThumb(i),
            if (photoCount < 6) _addPhotoTile(),
          ],
        ),
      ],
    );
  }

  Widget _photoThumb(int i) {
    final colors = [
      AppColors.secondary,
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      AppColors.danger,
      AppColors.ink,
    ];
    return Stack(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: colors[i % colors.length].withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.image_outlined, color: colors[i % colors.length]),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: () => setState(() => photoCount--),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppColors.ink,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addPhotoTile() {
    return GestureDetector(
      onTap: () => setState(() => photoCount++),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line, style: BorderStyle.solid),
        ),
        child: const Icon(Icons.add_a_photo_outlined, color: AppColors.inkSoft),
      ),
    );
  }

  Widget _stepSchedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Where and when?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 16),
        const Text(
          'Service address',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        ...kSavedAddresses.map(
          (a) => RadioListTile<String>(
            value: a,
            groupValue: address,
            onChanged: (v) => setState(() => address = v!),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
            title: Text(a, style: const TextStyle(fontSize: 13.5)),
          ),
        ),
        TextButton.icon(
          onPressed: () => _snack(context, 'Add-address form (demo)'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add new address'),
        ),
        const SizedBox(height: 10),
        const Text(
          'Preferred date',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        _pickerRow(
          Icons.calendar_today_outlined,
          date,
          () => _snack(context, 'Date picker (demo)'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Preferred time',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        _pickerRow(
          Icons.schedule_outlined,
          time,
          () => _snack(context, 'Time picker (demo)'),
        ),
      ],
    );
  }

  Widget _pickerRow(IconData icon, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.inkSoft),
            const SizedBox(width: 10),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }

  Widget _stepReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review your request',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 16),
        _reviewRow('Service', selectedService ?? '—'),
        _reviewRow(
          'Description',
          descController.text.isEmpty
              ? 'No description added'
              : descController.text,
        ),
        _reviewRow('Attachments', '$photoCount file(s)'),
        _reviewRow('Address', address),
        _reviewRow('Date & time', '$date · $time'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.secondary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "You'll receive a confirmation and a quote from Twins Handyman shortly after submitting.",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.secondaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmation(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.successBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 44,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Request submitted!',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              'We received your $selectedService request. Twins Handyman will review it and send a quote to your account soon.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 14),
            ),
            const SizedBox(height: 28),
            PrimaryCta(
              label: 'Track this request',
              onTap: () {
                setState(() {
                  submitted = false;
                  step = 0;
                  selectedService = null;
                  descController.clear();
                  photoCount = 0;
                });
                final state = context
                    .findAncestorStateOfType<_RootShellState>();
                state?.setState(() => state.index = 3);
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                setState(() {
                  submitted = false;
                  step = 0;
                  selectedService = null;
                  descController.clear();
                  photoCount = 0;
                });
                final state = context
                    .findAncestorStateOfType<_RootShellState>();
                state?.setState(() => state.index = 0);
              },
              child: const Text(
                'Back to home',
                style: TextStyle(color: AppColors.inkSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmbeddedHeader extends StatelessWidget {
  final int step;
  const _EmbeddedHeader({required this.step});
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Request a service',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  final int step;
  const _StepProgress({required this.step});
  @override
  Widget build(BuildContext context) {
    const labels = ['Service', 'Details', 'Schedule', 'Review'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i <= step;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(
                      right: i == labels.length - 1 ? 0 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : AppColors.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ============================================================================
// QUOTES TAB
// ============================================================================
class QuotesTab extends StatefulWidget {
  const QuotesTab({super.key});
  @override
  State<QuotesTab> createState() => _QuotesTabState();
}

class _QuotesTabState extends State<QuotesTab> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              'Your quotes',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          ...kQuotes.map(
            (q) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: _QuoteCard(
                quote: q,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuoteDetailScreen(quote: q),
                    ),
                  );
                  setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final QuoteItem quote;
  final VoidCallback onTap;
  const _QuoteCard({required this.quote, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  quote.service,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                StatusChip(quote.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${quote.id} · Issued ${quote.dateIssued}',
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Divider(color: AppColors.line, height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${quote.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const Row(
                  children: [
                    Text(
                      'View details',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppColors.secondary,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class QuoteDetailScreen extends StatefulWidget {
  final QuoteItem quote;
  const QuoteDetailScreen({super.key, required this.quote});
  @override
  State<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends State<QuoteDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final q = widget.quote;
    final pending = q.status == 'Sent' || q.status == 'Pending';
    return Scaffold(
      appBar: AppBar(title: Text(q.id)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                q.service,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              StatusChip(q.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Issued ${q.dateIssued}',
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.inkSoft,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  q.address,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (final line in q.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            line.label,
                            style: const TextStyle(fontSize: 13.5),
                          ),
                        ),
                        Text(
                          '\$${line.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 22, color: AppColors.line),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '\$${q.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notes',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  q.notes,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => _showTerms(context),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('View terms & conditions'),
          ),
          if (pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => q.status = 'Rejected');
                      _snack(context, 'Quote declined');
                    },
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => q.status = 'Accepted');
                      _snack(
                        context,
                        'Quote accepted — scheduling will follow',
                      );
                    },
                    child: const Text('Accept quote'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showTerms(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Terms & Conditions',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 12),
              const Text(
                '1. Quotes are valid for 14 days from the date of issue.\n\n'
                '2. A 50% deposit is required to confirm scheduling on jobs over \$150.\n\n'
                '3. Final pricing may adjust if job scope changes on-site; any change will be communicated before work proceeds.\n\n'
                '4. Cancellations within 24 hours of a scheduled appointment may incur a service fee.\n\n'
                '5. Twins Handyman LLC is licensed and insured for all listed service categories.\n\n'
                '(Demo placeholder text — replace with final legal terms.)',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.inkSoft,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// JOBS TAB — scheduling & tracking
// ============================================================================
class JobsTab extends StatefulWidget {
  const JobsTab({super.key});
  @override
  State<JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<JobsTab> {
  bool showUpcoming = true;

  @override
  Widget build(BuildContext context) {
    final upcoming = kJobs.where((j) => j.stage < 4).toList();
    final past = kJobs.where((j) => j.stage == 4).toList();
    final list = showUpcoming ? upcoming : past;

    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Your jobs',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _toggleBtn(
                    'Upcoming',
                    showUpcoming,
                    () => setState(() => showUpcoming = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _toggleBtn(
                    'Past',
                    !showUpcoming,
                    () => setState(() => showUpcoming = false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text(
                      'Nothing here yet',
                      style: TextStyle(color: AppColors.inkSoft),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    children: list
                        .map(
                          (j) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _JobCard(job: j),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.inkSoft,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final JobItem job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  job.service,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                StatusChip(_stages[job.stage]),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 13,
                  color: AppColors.inkSoft,
                ),
                const SizedBox(width: 5),
                Text(
                  '${job.date} · ${job.time}',
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MiniTimeline(stage: job.stage),
          ],
        ),
      ),
    );
  }
}

class _MiniTimeline extends StatelessWidget {
  final int stage;
  const _MiniTimeline({required this.stage});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_stages.length, (i) {
        final done = i <= stage;
        return Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(right: i == _stages.length - 1 ? 0 : 4),
            decoration: BoxDecoration(
              color: done ? AppColors.success : AppColors.line,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}

class JobDetailScreen extends StatelessWidget {
  final JobItem job;
  const JobDetailScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(job.id)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            job.service,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.inkSoft,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  job.address,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 14,
                color: AppColors.inkSoft,
              ),
              const SizedBox(width: 4),
              Text(
                '${job.date} · ${job.time}',
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Job status',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 16),
          Column(
            children: List.generate(_stages.length, (i) {
              final done = i <= job.stage;
              final isLast = i == _stages.length - 1;
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: done ? AppColors.success : AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: done ? AppColors.success : AppColors.line,
                              width: 2,
                            ),
                          ),
                          child: done
                              ? const Icon(
                                  Icons.check,
                                  size: 13,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: i < job.stage
                                  ? AppColors.success
                                  : AppColors.line,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _stages[i],
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: done ? AppColors.ink : AppColors.inkSoft,
                              ),
                            ),
                            if (i == job.stage)
                              const Padding(
                                padding: EdgeInsets.only(top: 3),
                                child: Text(
                                  'Current status',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showReschedule(context),
                  icon: const Icon(Icons.event_repeat, size: 18),
                  label: const Text('Reschedule'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MessagesScreen()),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Contact'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  size: 18,
                  color: AppColors.secondary,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "You'll get a reminder 24 hours before this appointment.",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.secondaryDark,
                    ),
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

// ============================================================================
// PAYMENTS
// ============================================================================
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final due = kInvoices
        .where((i) => i.status == 'Due')
        .fold(0.0, (s, i) => s + i.amount);
    return Scaffold(
      appBar: AppBar(title: const Text('Payments & invoices')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total balance due',
                  style: TextStyle(color: Color(0xFFB9BFC6), fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  '\$${due.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: due > 0 ? () => _showPay(context, due) : null,
                    icon: const Icon(Icons.lock_outline, size: 16),
                    label: const Text('Pay securely'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Invoices',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ...kInvoices.map(
            (inv) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.infoBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_outlined,
                      color: AppColors.secondary,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inv.job,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${inv.id} · ${inv.date}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${inv.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      StatusChip(inv.status),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPay(BuildContext context, double amount) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Checkout',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              'Amount due: \$${amount.toStringAsFixed(2)}',
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.credit_card, color: AppColors.inkSoft),
                  SizedBox(width: 10),
                  Text(
                    'Visa •••• 4242',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Spacer(),
                  Icon(Icons.check_circle, color: AppColors.success, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 18),
            PrimaryCta(
              label: 'Confirm payment',
              onTap: () {
                Navigator.pop(context);
                _snack(
                  context,
                  'Payment successful — receipt sent to your email (demo)',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MESSAGES / CONTACT
// ============================================================================
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final List<ChatMessage> messages = List.of(kMessages);
  final controller = TextEditingController();

  void _send() {
    if (controller.text.trim().isEmpty) return;
    setState(() {
      messages.add(ChatMessage(true, controller.text.trim(), 'Now'));
      controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            TwinsLogo(size: 32),
            SizedBox(width: 10),
            Text('Twins Handyman'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _snack(context, 'Calling (555) 010-2938 (demo)'),
            icon: const Icon(Icons.call_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final m = messages[i];
                return Align(
                  alignment: m.fromMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    constraints: const BoxConstraints(maxWidth: 270),
                    decoration: BoxDecoration(
                      color: m.fromMe ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(14),
                        topRight: const Radius.circular(14),
                        bottomLeft: Radius.circular(m.fromMe ? 14 : 3),
                        bottomRight: Radius.circular(m.fromMe ? 3 : 14),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.text,
                          style: TextStyle(
                            color: m.fromMe ? Colors.white : AppColors.ink,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m.time,
                          style: TextStyle(
                            color: m.fromMe
                                ? Colors.white70
                                : AppColors.inkSoft,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Message Twins Handyman...',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: _send,
                  icon: const Icon(Icons.send, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ACCOUNT TAB
// ============================================================================
class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'S',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sarah Malik',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'sarah.malik@email.com',
                    style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
                  ),
                  Text(
                    '+92 300 1234567',
                    style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _accountSection('Saved addresses', [
            for (final a in kSavedAddresses)
              _accountTile(Icons.location_on_outlined, a, () {}),
            _accountTile(Icons.add, 'Add new address', () {}),
          ]),
          const SizedBox(height: 18),
          _accountSection('Activity', [
            _accountTile(
              Icons.payments_outlined,
              'Payments & invoices',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentsScreen()),
              ),
            ),
            _accountTile(
              Icons.chat_bubble_outline,
              'Messages',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MessagesScreen()),
              ),
            ),
            _accountTile(
              Icons.notifications_outlined,
              'Notification preferences',
              () {},
            ),
          ]),
          const SizedBox(height: 18),
          _accountSection('Support', [
            _accountTile(Icons.call_outlined, 'Call Twins Handyman', () {}),
            _accountTile(Icons.help_outline, 'FAQ', () {}),
            _accountTile(
              Icons.description_outlined,
              'Terms & conditions',
              () {},
            ),
            _accountTile(Icons.privacy_tip_outlined, 'Privacy policy', () {}),
          ]),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.dangerBg, width: 1.4),
              ),
              child: const Text('Log out'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountSection(String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppColors.inkSoft,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: tiles),
        ),
      ],
    );
  }

  Widget _accountTile(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}
