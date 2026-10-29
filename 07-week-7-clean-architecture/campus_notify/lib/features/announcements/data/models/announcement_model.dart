import '../../domain/entities/announcement.dart';

/// Representasi data luar dari pengumuman.
///
/// Satu-satunya tempat yang tahu bentuk JSON pengumuman. `Announcement` di
/// `domain` tidak pernah melihat `Map<String, dynamic>`.
class AnnouncementModel extends Announcement {
  const AnnouncementModel({
    required super.id,
    required super.title,
    required super.body,
  });

  factory AnnouncementModel.fromJson(Map<String, Object?> json) {
    return AnnouncementModel(
      id: (json['id'] as num?)?.toString() ?? (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
    );
  }

  Map<String, Object?> toJson() => {'id': id, 'title': title, 'body': body};

  /// Dipanggil tepat di batas `data -> domain`.
  Announcement toEntity() => Announcement(id: id, title: title, body: body);
}
