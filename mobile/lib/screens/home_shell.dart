import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ticket.dart';
import '../services/notifications_controller.dart';
import '../theme.dart';
import 'create_ticket_screen.dart';
import 'dashboard_screen.dart';
import 'knowledge_base_screen.dart';
import 'profile_screen.dart';
import 'ticket_detail_screen.dart';
import 'ticket_list_screen.dart';

/// Signed-in shell: Home, Tickets, Help Center and Profile, with a raised
/// "New ticket" button in the middle of the bottom bar.
/// Exists only while a user is signed in.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  late final NotificationsController _notifications;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _notifications = context.read<NotificationsController>();
    WidgetsBinding.instance.addObserver(this);
    // After the first frame, so listeners are not notified during build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifications.start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifications.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _notifications.refresh();
  }

  void _select(int index) => setState(() => _index = index);

  Future<void> _newTicket() async {
    final created = await Navigator.of(context).push<Ticket>(
      MaterialPageRoute(builder: (_) => const CreateTicketScreen()),
    );
    if (created == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TicketDetailScreen(ticketId: created.id, ticketNumber: created.number),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(onOpenTab: _select, onNewTicket: _newTicket),
          const TicketListScreen(),
          const KnowledgeBaseScreen(),
          const ProfileScreen(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _NewTicketButton(onPressed: _newTicket),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        height: 72,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            _NavItem(icon: Icons.space_dashboard_rounded, label: 'Home', selected: _index == 0, onTap: () => _select(0)),
            _NavItem(icon: Icons.confirmation_number_rounded, label: 'Tickets', selected: _index == 1, onTap: () => _select(1)),
            const SizedBox(width: 72),
            _NavItem(icon: Icons.menu_book_rounded, label: 'Help', selected: _index == 2, onTap: () => _select(2)),
            _NavItem(icon: Icons.person_rounded, label: 'Profile', selected: _index == 3, onTap: () => _select(3)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.muted;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkResponse(
          onTap: onTap,
          radius: 36,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(fontSize: 11.5, color: color, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewTicketButton extends StatelessWidget {
  const _NewTicketButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'New ticket',
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.brand,
          boxShadow: AppShadows.glow(AppColors.primary),
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
          ),
        ),
      ),
    );
  }
}
