// Verify that the column count matches the placeholder count in the maternal care INSERT statement

const maternalInsertQuery = `
  INSERT INTO patients (
    user_id, mother_fullname, father_fullname, child_fullname, dob,
    place_of_birth, birth_weight, birth_height, sex, address, status, service_type,
    record_type, record_description,
    family_serial_number, contact_number, spouse_name, living_children_count, 
    monthly_income, religion, city, province, age, education, occupation, 
    birth_attendant, facility_type
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
`;

// Extract column names properly
const columnsSection = maternalInsertQuery.match(/INSERT INTO patients \(([^)]+)\)/);
if (columnsSection) {
  // Split by comma and clean up whitespace
  const columns = columnsSection[1].split(',').map(col => col.trim());
  const columnCount = columns.length;
  
  // Count placeholders
  const placeholderCount = (maternalInsertQuery.match(/\?/g) || []).length;
  
  console.log(`Columns: ${columnCount}`);
  console.log(`Placeholders: ${placeholderCount}`);
  console.log(`Match: ${columnCount === placeholderCount ? '✅ YES' : '❌ NO'}`);
  
  if (columnCount !== placeholderCount) {
    console.log(`\n❌ MISMATCH DETECTED!`);
    console.log(`Difference: ${Math.abs(columnCount - placeholderCount)}`);
    console.log(`\nColumns:`);
    columns.forEach((col, index) => {
      console.log(`  ${index + 1}. ${col}`);
    });
  } else {
    console.log(`\n✅ Column count matches placeholder count!`);
  }
} else {
  console.log('Could not extract columns section');
}