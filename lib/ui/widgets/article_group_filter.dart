import 'package:flutter/material.dart';

/// A1-Nachtrag (Kay, 15.11.2026): Artikel nach **Artikelgruppe** filtern —
/// in der Artikelübersicht und in der Artikelauswahl einer Position,
/// offline und online gleich. Filtert nur die Anzeige; Artikel, Preise und
/// Kalkulation bleiben unverändert. Die Artikelgruppe im Stamm ist keine
/// Positionsgruppe im Beleg.
sealed class ArticleGroupFilter {
  const ArticleGroupFilter();
  bool matches(String? articleGroupId);
}

/// Standard: alle Artikel.
class AllArticleGroups extends ArticleGroupFilter {
  const AllArticleGroups();
  @override
  bool matches(String? articleGroupId) => true;
  @override
  bool operator ==(Object other) => other is AllArticleGroups;
  @override
  int get hashCode => 0;
}

/// Nur Artikel ohne Gruppe.
class NoArticleGroup extends ArticleGroupFilter {
  const NoArticleGroup();
  @override
  bool matches(String? articleGroupId) => articleGroupId == null;
  @override
  bool operator ==(Object other) => other is NoArticleGroup;
  @override
  int get hashCode => 1;
}

/// Nur Artikel einer bestimmten Gruppe (auch wenn sie leer ist).
class SingleArticleGroup extends ArticleGroupFilter {
  const SingleArticleGroup(this.id);
  final String id;
  @override
  bool matches(String? articleGroupId) => articleGroupId == id;
  @override
  bool operator ==(Object other) => other is SingleArticleGroup && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

/// Auswahlfeld „Artikelgruppe“. [groups] sind die Gruppen der aktiven
/// Firma (id, Name); „Ohne Gruppe“ erscheint nur, wenn es gruppenlose
/// Artikel gibt. Eine nicht mehr vorhandene Auswahl fällt auf „Alle“ zurück.
class ArticleGroupFilterField extends StatelessWidget {
  const ArticleGroupFilterField({
    super.key,
    required this.groups,
    required this.hasUngrouped,
    required this.value,
    required this.onChanged,
  });

  final List<({String id, String name})> groups;
  final bool hasUngrouped;
  final ArticleGroupFilter value;
  final ValueChanged<ArticleGroupFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <ArticleGroupFilter, String>{
      const AllArticleGroups(): 'Alle Gruppen',
      if (hasUngrouped) const NoArticleGroup(): 'Ohne Gruppe',
      for (final g in [...groups]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())))
        SingleArticleGroup(g.id): g.name,
    };
    return DropdownButtonFormField<ArticleGroupFilter>(
      key: const Key('article-group-filter'),
      isExpanded: true,
      initialValue: options.containsKey(value) ? value : const AllArticleGroups(),
      decoration: const InputDecoration(labelText: 'Artikelgruppe', prefixIcon: Icon(Icons.filter_list)),
      items: [
        for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) => onChanged(v ?? const AllArticleGroups()),
    );
  }
}

/// Suche + Gruppe gemeinsam: Name enthält [query] (ohne Groß/Klein) und
/// Gruppe passt zum Filter.
bool articleMatches({
  required String name,
  required String? articleGroupId,
  required String query,
  required ArticleGroupFilter filter,
}) =>
    filter.matches(articleGroupId) && (query.isEmpty || name.toLowerCase().contains(query.toLowerCase()));
