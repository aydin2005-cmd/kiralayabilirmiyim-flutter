class TurkeyLocations {
  static const List<String> cities = [
    'İstanbul',
    'Ankara',
    'İzmir',
    'Bursa',
    'Antalya',
    'Kocaeli',
    'Muğla',
    'Eskişehir',
    'Adana',
    'Konya',
  ];

  static const Map<String, List<String>> districts = {
    'İstanbul': [
      'Kadıköy',
      'Beşiktaş',
      'Şişli',
      'Üsküdar',
      'Ataşehir',
      'Bakırköy',
      'Sarıyer',
      'Maltepe',
      'Beylikdüzü',
      'Pendik',
    ],
    'Ankara': ['Çankaya', 'Yenimahalle', 'Keçiören', 'Etimesgut', 'Mamak'],
    'İzmir': ['Konak', 'Karşıyaka', 'Bornova', 'Balçova', 'Çeşme'],
    'Bursa': ['Nilüfer', 'Osmangazi', 'Yıldırım', 'Mudanya'],
    'Antalya': ['Muratpaşa', 'Konyaaltı', 'Kepez', 'Alanya'],
    'Kocaeli': ['İzmit', 'Gebze', 'Darıca', 'Kartepe'],
    'Muğla': ['Bodrum', 'Fethiye', 'Marmaris', 'Menteşe'],
    'Eskişehir': ['Odunpazarı', 'Tepebaşı'],
    'Adana': ['Seyhan', 'Çukurova', 'Yüreğir'],
    'Konya': ['Selçuklu', 'Meram', 'Karatay'],
  };

  static List<String> districtsFor(String? city) {
    if (city == null) return const [];
    return districts[city] ?? const [];
  }
}
