class VehicleSegment {
  final String code;
  final String label;
  final String description;

  const VehicleSegment({
    required this.code,
    required this.label,
    required this.description,
  });

  String get displayText => '$label — $description';
}

class VehicleSegments {
  static const List<VehicleSegment> items = [
    VehicleSegment(code: 'A', label: 'A Segment', description: 'Küçük ekonomik'),
    VehicleSegment(code: 'B', label: 'B Segment', description: 'Kompakt'),
    VehicleSegment(code: 'C', label: 'C Segment', description: 'Orta segment'),
    VehicleSegment(code: 'D', label: 'D Segment', description: 'Üst segment'),
    VehicleSegment(code: 'E', label: 'E Segment', description: 'Premium / lüks'),
  ];

  static VehicleSegment? byCode(String? code) {
    if (code == null) return null;
    for (final item in items) {
      if (item.code == code) return item;
    }
    return null;
  }
}
