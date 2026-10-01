class Dictionary {
  final int? id;
  final String name;

  const Dictionary({
    this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory Dictionary.fromMap(Map<String, dynamic> map) {
    return Dictionary(
      id: (map['id'] as num?)?.toInt(),
      name: map['name']?.toString() ?? '',
    );
  }
}
