import 'package:flutter/material.dart';
import '../controllers/app_state_provider.dart';
import '../widgets/ticket_card.dart';

class InstalacionesScreen extends StatefulWidget {
  const InstalacionesScreen({super.key});

  @override
  State<InstalacionesScreen> createState() => _InstalacionesScreenState();
}

class _InstalacionesScreenState extends State<InstalacionesScreen> {
  int _selectedCalendarIndex = 2;

  final List<Map<String, String>> _calendarDays = [
    {"day": "LUN", "date": "25"},
    {"day": "MAR", "date": "26"},
    {"day": "MIÉ", "date": "27"},
    {"day": "JUE", "date": "28"},
    {"day": "VIE", "date": "29"},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final orangeAccent = const Color(0xFFFF5A00);
    final state = AppStateProvider.of(context);
    final tickets = state.activeTickets;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      shape: const CircleBorder(),
                    ),
                    icon: Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  Text(
                    "INSTALACIONES",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF111827) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(_calendarDays.length, (index) {
                    final item = _calendarDays[index];
                    final isActive = index == _selectedCalendarIndex;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCalendarIndex = index;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive
                              ? (isDark ? Colors.white : const Color(0xFF334155))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : [],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item["day"]!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? (isDark ? Colors.black : Colors.white)
                                    : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item["date"]!,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isActive
                                    ? (isDark ? Colors.black : Colors.white)
                                    : theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: tickets.isEmpty
                    ? _buildEmptyState(theme, isDark, orangeAccent)
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: tickets.length,
                        itemBuilder: (context, index) {
                          return TicketCard(
                            ticket: tickets[index],
                            index: index,
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark, Color accentColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.inbox_outlined,
          size: 56,
          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.3),
        ),
        const SizedBox(height: 16),
        Text(
          "Sin instalaciones",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "No tienes tickets de instalaciones asignados en HubSpot para el día de hoy.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.55),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
