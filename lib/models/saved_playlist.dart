/// Model untuk playlist tersimpan di database.
library;

class SavedPlaylist {
  final int? id;
  final String name;
  final int itemCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavedPlaylist({
    this.id,
    required this.name,
    this.itemCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SavedPlaylist.fromMap(Map<String, dynamic> map) {
    return SavedPlaylist(
      id: map['id'] as int?,
      name: map['name'] as String,
      itemCount: map['item_count'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  SavedPlaylist copyWith({
    int? id,
    String? name,
    int? itemCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedPlaylist(
      id: id ?? this.id,
      name: name ?? this.name,
      itemCount: itemCount ?? this.itemCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'SavedPlaylist(id: $id, name: $name, items: $itemCount)';
}
