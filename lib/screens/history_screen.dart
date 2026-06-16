import 'package:flutter/material.dart';
import '../services/api_client.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool loading = true;
  String? error;
  List<dynamic> items = [];
  final api = ApiClient();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final response = await api.get('/applications/my');
      final data = response['data'];
      if (data is List) {
        items = data;
      } else {
        // Backend doğrudan liste döndürürse ApiClient bunu data alanına koyar.
        items = [];
      }
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  String label(String? value) {
    switch (value) {
      case 'home_rental':
        return 'Ev Kiralama';
      case 'car_rental':
        return 'Araç Kiralama';
      default:
        return value ?? '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Geçmiş Değerlendirmelerim')),
      body: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: error != null
            ? Center(child: Text(error!))
            : items.isEmpty
                ? const Center(child: Text('Henüz değerlendirme bulunmuyor.'))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index] as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          title:
                              Text(label(item['application_type']?.toString())),
                          subtitle: Text('Son durum: ${item['status'] ?? '-'}'),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
