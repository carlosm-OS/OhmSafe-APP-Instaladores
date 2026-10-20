import 'package:flutter/material.dart';

import 'movimiento.dart';
import '../models/ticket.dart';

class TicketCard extends StatefulWidget {
  final Ticket ticket;
  final int index;

  const TicketCard({super.key, required this.ticket, required this.index});

  @override
  State<TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<TicketCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final urgentRed = cs.error;

    // Entrada escalonada con el movimiento de GO (2026-10-20): fundido + sube 8 px, 260 ms.
    return EntradaSuave(
      index: widget.index,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? cs.outline.withValues(alpha: 0.5) : cs.outlineVariant.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (widget.ticket.isUrgent)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: urgentRed,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: urgentRed.withValues(alpha: 0.6), blurRadius: 4, spreadRadius: 1)],
                  ),
                ),
              ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: widget.ticket.isUrgent ? 16 : 0),
                  child: Text(
                    widget.ticket.title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color, height: 1.25),
                  ),
                ),
                if (widget.ticket.details.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: widget.ticket.details.map((detail) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? cs.outline.withValues(alpha: 0.3) : cs.outlineVariant),
                        ),
                        child: Text(
                          detail,
                          style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.65), fontWeight: FontWeight.w500),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.08)),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: isDark ? cs.surface : cs.primaryContainer, shape: BoxShape.circle),
                      child: Icon(Icons.person, size: 14, color: isDark ? theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5) : cs.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.ticket.user,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8)),
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
