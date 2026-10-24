import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../../../domain/services/online_session.dart';

/// Artikel der Online-Firma (Lesen) — Pflege folgt mit Lieferanten/
/// Artikelgruppen im Server.
class OnlineArticlesScreen extends StatefulWidget {
  const OnlineArticlesScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlineArticlesScreen> createState() => _OnlineArticlesScreenState();
}

class _OnlineArticlesScreenState extends State<OnlineArticlesScreen> {
  late Future<List<OnlineArticle>> _future = widget.session.client.articles();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OnlineArticle>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text(describeOnlineError(snapshot.error!)));
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        final articles = snapshot.data!;
        if (articles.isEmpty) return const Center(child: Text('Keine Artikel vorhanden.'));
        return RefreshIndicator(
          onRefresh: () async => setState(() {
            _future = widget.session.client.articles();
          }),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: articles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final a = articles[index];
              final price = a.salePriceCents == null ? 'kein Preis' : '${Money.fromCents(a.salePriceCents!)} netto';
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(a.name),
                  subtitle: Text(a.unit == null ? price : '$price / ${a.unit}'),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
