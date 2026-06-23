import 'package:drift/drift.dart';
import 'package:sentery_app/core/database/app_database.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Stream<AppSetting?> watchSettings() {
    return (select(appSettings)..limit(1)).watchSingleOrNull();
  }

  Future<AppSetting?> getSettings() {
    return (select(appSettings)..limit(1)).getSingleOrNull();
  }

  Future<void> updateSettings(AppSettingsCompanion settings) async {
    final existing = await getSettings();
    if (existing != null) {
      await (update(appSettings)..where((t) => t.id.equals(existing.id))).write(settings);
    } else {
      await into(appSettings).insert(settings);
    }
  }
}
