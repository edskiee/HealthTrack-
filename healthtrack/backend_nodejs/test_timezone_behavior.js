/**
 * Test script to understand the actual timezone behavior
 */

console.log('=== Timezone Investigation ===');
console.log('Current timezone offset (minutes):', new Date().getTimezoneOffset());
console.log('Current timezone:', Intl.DateTimeFormat().resolvedOptions().timeZone);

console.log('\n=== Testing Date Parsing Behavior ===');

// Test case 1: YYYY-MM-DD with T00:00:00
const dateStr1 = '2026-03-02';
const parsed1 = new Date(dateStr1 + 'T00:00:00');
console.log(`\nInput: "${dateStr1}T00:00:00"`);
console.log('Parsed Date:', parsed1);
console.log('ISO String:', parsed1.toISOString());
console.log('Local String:', parsed1.toString());
console.log('Year:', parsed1.getFullYear());
console.log('Month:', parsed1.getMonth() + 1);
console.log('Date:', parsed1.getDate());

// Test case 2: YYYY-MM-DD without time
const dateStr2 = '2026-03-02';
const parsed2 = new Date(dateStr2);
console.log(`\nInput: "${dateStr2}"`);
console.log('Parsed Date:', parsed2);
console.log('ISO String:', parsed2.toISOString());
console.log('Local String:', parsed2.toString());
console.log('Year:', parsed2.getFullYear());
console.log('Month:', parsed2.getMonth() + 1);
console.log('Date:', parsed2.getDate());

// Test case 3: Simulating Asia/Manila timezone (UTC+8)
console.log('\n=== Simulating UTC Interpretation ===');
const utcDate = new Date('2026-03-02T00:00:00Z'); // Explicit UTC
console.log('UTC Date:', utcDate);
console.log('ISO String:', utcDate.toISOString());
console.log('Local String:', utcDate.toString());
console.log('Local Year:', utcDate.getFullYear());
console.log('Local Month:', utcDate.getMonth() + 1);
console.log('Local Date:', utcDate.getDate());

// Test case 4: What happens in Asia/Manila timezone
console.log('\n=== Expected Bug Scenario (Asia/Manila UTC+8) ===');
console.log('If server is in Asia/Manila (UTC+8):');
console.log('- Input: "2026-03-02T00:00:00"');
console.log('- Interpreted as: 2026-03-02 00:00:00 LOCAL time');
console.log('- This should NOT cause date shift');
console.log('');
console.log('But if interpreted as UTC:');
console.log('- Input: "2026-03-02T00:00:00" (treated as UTC)');
console.log('- In UTC+8: 2026-03-02 00:00:00 UTC = 2026-03-02 08:00:00 Manila');
console.log('- This should NOT cause date shift either');
console.log('');
console.log('The bug occurs when:');
console.log('- Date is stored/compared in UTC but displayed in local time');
console.log('- Or when date boundaries are crossed during conversion');
