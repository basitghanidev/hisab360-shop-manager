import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/database/database_provider.dart';

final settingsDaoProvider = Provider((ref) => ref.watch(databaseProvider).settingsDao);

final settingsStreamProvider = StreamProvider<AppSetting?>((ref) {
  return ref.watch(settingsDaoProvider).watchSettings();
});
