part of '../repository_postgres.dart';

mixin _PostgresSuppliers implements SupplierStore {
  Future<Result> _q(String sql, [Map<String, Object?> parameters = const {}]);

  static const _supplierColumns = 'id, company_id, name, address, email, phone, vat_id, contact_person, notes, '
      'minimum_order_quantity, delivery_terms, created_at';

  Supplier _toSupplier(ResultRow r) => Supplier(
        id: r[0] as String,
        companyId: r[1] as String,
        name: r[2] as String,
        address: r[3] as String?,
        email: r[4] as String?,
        phone: r[5] as String?,
        vatId: r[6] as String?,
        contactPerson: r[7] as String?,
        notes: r[8] as String?,
        minimumOrderQuantity: r[9] as String?,
        deliveryTerms: r[10] as String?,
        createdAt: r[11] as DateTime,
      );

  Map<String, Object?> _supplierParams(Supplier s) => {
        'id': s.id,
        'companyId': s.companyId,
        'name': s.name,
        'address': s.address,
        'email': s.email,
        'phone': s.phone,
        'vatId': s.vatId,
        'contact': s.contactPerson,
        'notes': s.notes,
        'moq': s.minimumOrderQuantity,
        'terms': s.deliveryTerms,
        'createdAt': s.createdAt,
      };

  @override
  Future<List<Supplier>> listSuppliers(String companyId, {String? query}) async {
    final result = await _q(
      'SELECT $_supplierColumns FROM suppliers WHERE company_id = @companyId '
      "AND (@q = '' OR position(lower(@q) in lower(name)) > 0) ORDER BY lower(name)",
      {'companyId': companyId, 'q': query ?? ''},
    );
    return [for (final r in result) _toSupplier(r)];
  }

  @override
  Future<Supplier?> findSupplier(String companyId, String id) async {
    final result = await _q(
      'SELECT $_supplierColumns FROM suppliers WHERE company_id = @companyId AND id = @id',
      {'companyId': companyId, 'id': id},
    );
    return result.isEmpty ? null : _toSupplier(result.first);
  }

  @override
  Future<void> createSupplier(Supplier supplier) async {
    await _q(
      'INSERT INTO suppliers ($_supplierColumns) VALUES (@id, @companyId, @name, @address, @email, @phone, @vatId, '
      '@contact, @notes, @moq, @terms, @createdAt)',
      _supplierParams(supplier),
    );
  }

  @override
  Future<bool> updateSupplier(Supplier supplier) async {
    final result = await _q(
      'UPDATE suppliers SET name = @name, address = @address, email = @email, phone = @phone, vat_id = @vatId, '
      'contact_person = @contact, notes = @notes, minimum_order_quantity = @moq, delivery_terms = @terms '
      'WHERE company_id = @companyId AND id = @id',
      _supplierParams(supplier)..remove('createdAt'),
    );
    return result.affectedRows > 0;
  }

  @override
  Future<bool> deleteSupplier(String companyId, String id) async {
    final result = await _q('DELETE FROM suppliers WHERE company_id = @companyId AND id = @id', {
      'companyId': companyId,
      'id': id,
    });
    return result.affectedRows > 0;
  }

  ArticleGroup _toGroup(ResultRow r) => ArticleGroup(
        id: r[0] as String,
        companyId: r[1] as String,
        name: r[2] as String,
        markupPercent: (r[3] as num).toDouble(),
        createdAt: r[4] as DateTime,
      );

  @override
  Future<List<ArticleGroup>> listArticleGroups(String companyId) async {
    final result = await _q(
      'SELECT id, company_id, name, markup_percent, created_at FROM article_groups WHERE company_id = @companyId '
      'ORDER BY lower(name)',
      {'companyId': companyId},
    );
    return [for (final r in result) _toGroup(r)];
  }

  @override
  Future<ArticleGroup?> findArticleGroup(String companyId, String id) async {
    final result = await _q(
      'SELECT id, company_id, name, markup_percent, created_at FROM article_groups '
      'WHERE company_id = @companyId AND id = @id',
      {'companyId': companyId, 'id': id},
    );
    return result.isEmpty ? null : _toGroup(result.first);
  }

  @override
  Future<void> createArticleGroup(ArticleGroup group) async {
    await _q(
      'INSERT INTO article_groups (id, company_id, name, markup_percent, created_at) '
      'VALUES (@id, @companyId, @name, @markup, @createdAt)',
      {'id': group.id, 'companyId': group.companyId, 'name': group.name, 'markup': group.markupPercent, 'createdAt': group.createdAt},
    );
  }

  @override
  Future<bool> updateArticleGroup(ArticleGroup group) async {
    final result = await _q(
      'UPDATE article_groups SET name = @name, markup_percent = @markup WHERE company_id = @companyId AND id = @id',
      {'id': group.id, 'companyId': group.companyId, 'name': group.name, 'markup': group.markupPercent},
    );
    return result.affectedRows > 0;
  }

  @override
  Future<bool> deleteArticleGroup(String companyId, String id) async {
    final result = await _q('DELETE FROM article_groups WHERE company_id = @companyId AND id = @id', {
      'companyId': companyId,
      'id': id,
    });
    return result.affectedRows > 0;
  }

  @override
  Future<List<ArticleSupplierPrice>> listArticlePrices(String companyId, {String? articleId}) async {
    final result = await _q(
      'SELECT article_id, supplier_id, purchase_price_cents FROM article_supplier_prices '
      'WHERE company_id = @companyId AND (@articleId::text IS NULL OR article_id = @articleId)',
      {'companyId': companyId, 'articleId': articleId},
    );
    return [
      for (final r in result)
        ArticleSupplierPrice(articleId: r[0] as String, supplierId: r[1] as String, purchasePriceCents: r[2] as int),
    ];
  }

  @override
  Future<void> setArticlePrice(String companyId, ArticleSupplierPrice price) async {
    await _q(
      'INSERT INTO article_supplier_prices (company_id, article_id, supplier_id, purchase_price_cents) '
      'VALUES (@companyId, @articleId, @supplierId, @cents) '
      'ON CONFLICT (article_id, supplier_id) DO UPDATE SET purchase_price_cents = EXCLUDED.purchase_price_cents',
      {'companyId': companyId, 'articleId': price.articleId, 'supplierId': price.supplierId, 'cents': price.purchasePriceCents},
    );
  }

  @override
  Future<bool> removeArticlePrice(String companyId, String articleId, String supplierId) async {
    final result = await _q(
      'DELETE FROM article_supplier_prices WHERE company_id = @companyId AND article_id = @articleId '
      'AND supplier_id = @supplierId',
      {'companyId': companyId, 'articleId': articleId, 'supplierId': supplierId},
    );
    return result.affectedRows > 0;
  }
}
