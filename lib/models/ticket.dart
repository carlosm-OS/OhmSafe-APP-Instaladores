class Ticket {
  final int id;
  final String title;
  final bool isUrgent;
  final List<String> details;
  final String user;

  Ticket({
    required this.id,
    required this.title,
    required this.isUrgent,
    required this.details,
    required this.user,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] as int,
      title: json['title'] as String,
      isUrgent: json['isUrgent'] as bool? ?? false,
      details: List<String>.from(json['details'] ?? []),
      user: json['user'] as String? ?? 'Técnico Asignado',
    );
  }
}
