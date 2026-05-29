# Maternal Care Registration Flow Fix

## Issue Identified
The maternal care patient registration was failing with a 500 error due to a mismatch between the number of columns and placeholders in the SQL INSERT statement.

## Root Cause
In the `authController.js` file, the maternal care patient INSERT query had:
- 27 columns in the column list
- Only 26 placeholders (?) in the VALUES clause

This caused a "Column count doesn't match value count at row 1" error (MySQL error ER_WRONG_VALUE_COUNT_ON_ROW).

## Fix Applied
Updated the SQL query in `backend_nodejs/src/controllers/authController.js` at line 130:

**Before:**
```sql
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
```

**After:**
```sql
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
```

Added one additional placeholder to match the 27 columns.

## Verification
After applying the fix:
1. ✅ Maternal care patient registration completes successfully (HTTP 200)
2. ✅ User account is created in the database
3. ✅ Patient record is created with all maternal care specific fields
4. ✅ Health record is automatically created for the patient
5. ✅ User can log in successfully
6. ✅ Patient appears in the admin "Manage Patients" section
7. ✅ Health record appears in the "Health Records" section
8. ✅ All data is properly categorized by service type (maternal)
9. ✅ Real-time updates work correctly across the system

## Test Results
```
🧪 Testing Complete Maternal Care Registration Flow
🚀 Starting Complete Maternal Care Registration Tests
📝 Test 1: Maternal Care Patient Registration
  Status: 200
  ✅ Maternal care registration successful
  User ID: 104
  Patient ID: 100
  Child Name: Test Maternal Child
  Service Type: maternal

🔐 Test 2: User Login
  Status: 200
  ✅ Login successful
  Service Type: maternal

📋 Test 3: Verify Patient Appears in Admin Panel
  ✅ Retrieved 26 patients from admin panel
  ✅ Test patient found in admin panel
  Patient ID: 100
  Service Type: maternal

📋 Test 4: Verify Health Records Are Created
  ✅ Retrieved 22 health records
  ✅ Test patient health record found
  Record ID: 41
  Title: Initial Health Record
  Record Type: Maternal Care

🏁 Complete Maternal Care Registration Testing Complete
🎉 All maternal care registration tests PASSED!
```

## Impact
This fix resolves the issue where newly registered maternal care patients were not appearing in the Health Records section on the admin side. The registration flow now works completely for both immunization and maternal care patients.