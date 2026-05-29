# List of Unused/Unreferenced Files That Can Be Safely Removed

This document lists files that appear to be unused, test files, or debug files that are not referenced anywhere in the codebase and can be safely removed without causing errors.

## JavaScript Test/Debug Files (Not Referenced)
1. `debug_login.js` - No references found
2. `simple_login_test.js` - No references found
3. `test_admin_login_debug.js` - No references found
4. `test_admin_login_simple.js` - No references found
5. `test_admin_modules.js` - No references found
6. `test_admin_user.js` - No references found
7. `test_api.dart` - No references found
8. `test_app_registration_simulation.js` - No references found
9. `test_appointment_booking.dart` - No references found
10. `test_appointment_booking_final.dart` - No references found
11. `test_appointment_node.js` - No references found
12. `test_database.js` - No references found
13. `test_db_query.js` - No references found
14. `test_health_record_fix.js` - No references found
15. `test_login.js` - No references found
16. `test_notification_fix.js` - No references found
17. `test_notification_system.js` - No references found
18. `test_notifications_complete.js` - No references found (mentioned in docs but file may not exist or not referenced in code)
19. `test_registration_complete.js` - No references found
20. `test_registration_fix.js` - No references found
21. `test_registration_fix_complete.js` - No references found
22. `test_service_type_registration.js` - No references found
23. `test_type_conversion.js` - No references found
24. `test_user_registration.js` - No references found

## Batch/PowerShell Scripts (Duplicates or Unreferenced)
1. `start_server.bat` - No references found
2. `update_database_schema.bat` - No references found
3. `update_database_with_notifications.bat` - Only referenced in documentation, likely duplicate

## SQL Files (Duplicates or Unreferenced)
1. `fix_notifications_simple.sql` - More comprehensive version exists
2. `fix_notifications_title_column.sql` - More comprehensive version exists

## Summary

These files can be safely removed as they:
- Are not referenced anywhere in the codebase
- Are test/debug files that were likely used during development
- Have duplicates or more comprehensive versions available
- Are not mentioned in any of the main documentation or setup instructions

Removing these files will:
✅ Reduce project clutter
✅ Improve project maintainability
✅ Reduce disk space usage
✅ Simplify the codebase structure

**Note:** Before removing any files, it's recommended to:
1. Backup the project
2. Verify that no local scripts or tools depend on these files
3. Check with team members if they're using any of these files locally