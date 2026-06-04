import 'package:flutter/foundation.dart' show kIsWeb;
import 'admin/main.admin.dart' as admin;
import 'main.mobile.dart' as mobile;

void main() {
  if (kIsWeb) {
    admin.main();
  } else {
    mobile.main();
  }
}