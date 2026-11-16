import 'package:flutter/material.dart';

enum DeleteGroupChoice { ungroup, deleteArticles }

Future<DeleteGroupChoice?> showArticleGroupDeleteDialog(BuildContext context, String name, int count) =>
    showDialog<DeleteGroupChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Artikelgruppe „$name“ löschen?'),
        content: Text('Aktuell sind $count Artikel zugeordnet. Was soll mit diesen Artikeln geschehen? '
            'Artikel mit Lagerhistorie können nicht gelöscht werden.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, DeleteGroupChoice.ungroup),
            child: const Text('Artikel ohne Gruppe behalten'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, DeleteGroupChoice.deleteArticles),
            child: const Text('Artikel löschen'),
          ),
        ],
      ),
    );
