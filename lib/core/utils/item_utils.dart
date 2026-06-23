import 'package:sentery_app/core/database/app_database.dart';

int getEffectiveCost(Item item) {
  if (item.averageCost > 0) return item.averageCost;
  if (item.lastPurchasePrice > 0) return item.lastPurchasePrice;
  if (item.purchasePrice > 0) return item.purchasePrice;
  return 0;
}
