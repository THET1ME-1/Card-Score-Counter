/// Компания (папка) игроков: именованный набор ссылок на игроков по имени.
/// Один игрок может состоять в нескольких компаниях (это не эксклюзивное
/// владение, а просто список участников).
class PlayerCompany {
  final String id;
  String name;
  List<String> members;

  PlayerCompany({
    required this.id,
    required this.name,
    required this.members,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members,
      };

  factory PlayerCompany.fromJson(Map<String, dynamic> json) => PlayerCompany(
        id: json['id'].toString(),
        name: (json['name'] ?? '').toString(),
        members: (json['members'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[],
      );

  PlayerCompany copy() =>
      PlayerCompany(id: id, name: name, members: List<String>.from(members));
}
