class Visit {
  final int? id;
  final String clientId;
  final String createdAt;

  Visit({this.id, required this.clientId, required this.createdAt});

  factory Visit.fromMap(Map<String, dynamic> map) {
    return Visit(
      id: map['id'],
      clientId: map['client_id'],
      createdAt: map['created_at'],
    );
  }
}