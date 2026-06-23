import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/services/backup_service.dart';
import 'package:drift/drift.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customStatement('SELECT 1');
  });

  tearDown(() async => db.close());

  test('ItemCategory serializes to Map<String,dynamic> without crash', () async {
    await db.into(db.itemCategories).insert(
      ItemCategoriesCompanion.insert(name: 'Pipes & Fittings'));

    final service = BackupService(db, testTempPath: '.');
    
    // Manual async execution for professional reliability
    final String result = await service.exportBackupAsString();

    // Ensure the result is valid JSON
    final decoded = jsonDecode(result) as Map<String, dynamic>;
    expect(decoded['item_categories'], isA<List>());
    expect((decoded['item_categories'] as List).first, isA<Map<String, dynamic>>());
  });

  test('Full round-trip: export → restore → data matches exactly', () async {
    // Insert known data
    await db.into(db.suppliers).insert(
      SuppliersCompanion.insert(name: 'Restore Supplier', currentBalance: const Value(50000), isActive: const Value(true)));
    await db.into(db.customers).insert(
      CustomersCompanion.insert(name: 'Restore Customer', currentBalance: const Value(25000), isActive: const Value(true)));

    final service = BackupService(db, testTempPath: '.');
    final jsonStr = await service.exportBackupAsString();

    // Wipe the database
    await db.delete(db.customers).go();
    await db.delete(db.suppliers).go();

    // Restore
    await service.restoreBackup(jsonStr);

    final restoredSuppliers = await db.select(db.suppliers).get();
    final restoredCustomers = await db.select(db.customers).get();

    expect(restoredSuppliers.any((s) => s.name == 'Restore Supplier'), isTrue);
    expect(restoredCustomers.any((c) => c.name == 'Restore Customer'), isTrue);
    expect(restoredSuppliers.first.currentBalance, equals(50000));
  });
}
