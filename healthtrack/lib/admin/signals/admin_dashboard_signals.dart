import 'package:flutter/foundation.dart';

final ValueNotifier<int> adminDashboardSignals = ValueNotifier<int>(0);

void pingAdminDashboard() {
  adminDashboardSignals.value++;
}
