'use strict';

process.on('unhandledRejection', (reason) => {
  console.error('unhandledRejection:', reason);
  process.exit(1);
});
process.on('uncaughtException', (err) => {
  console.error('uncaughtException:', err);
  process.exit(1);
});

require('dotenv').config({ path: __dirname + '/.env' });
const mysql = require('mysql2/promise');

async function run() {
  const conn = await mysql.createConnection({
    host:     process.env.DB_HOST,
    port:     Number(process.env.DB_PORT) || 3306,
    user:     process.env.DB_USER,
    password: process.env.DB_PASS,
    database: process.env.DB_NAME,
    ssl:      { rejectUnauthorized: false },
  });

  console.log('Connected to', process.env.DB_HOST);

  // Helper: check index existence
  async function indexExists(table, indexName, seqCheck) {
    const seqFilter = seqCheck ? 'AND SEQ_IN_INDEX=2' : '';
    const [[row]] = await conn.query(
      `SELECT COUNT(*) AS n FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=? AND INDEX_NAME=? ${seqFilter}`,
      [table, indexName]
    );
    return Number(row.n) > 0;
  }

  // Helper: run ALTER and capture any error
  async function addIndex(table, indexName, cols) {
    const sql = `ALTER TABLE \`${table}\` ADD INDEX \`${indexName}\` (${cols})`;
    console.log('  SQL:', sql);
    return new Promise((resolve, reject) => {
      conn.connection.query(sql, (err, result) => {
        if (err) reject(err);
        else resolve(result);
      });
    });
  }

  // ── 1. patients(service_type, created_at) ────────────────────────────────
  if (await indexExists('patients', 'idx_patients_service_created')) {
    console.log('SKIP  idx_patients_service_created — already exists');
  } else {
    console.log('CREATE idx_patients_service_created ON patients(service_type, created_at)');
    await addIndex('patients', 'idx_patients_service_created', '`service_type`, `created_at`');
    console.log('  ✓ created');
  }

  // ── 2. health_records(patient_id, created_at) ────────────────────────────
  // idx_patient_created already exists but may be two single-col indexes.
  // Only create new composite if the 2nd column (seq=2) is missing.
  if (await indexExists('health_records', 'idx_patient_created', true)) {
    console.log('SKIP  health_records composite idx_patient_created — already exists');
  } else if (await indexExists('health_records', 'idx_health_records_patient_created')) {
    console.log('SKIP  idx_health_records_patient_created — already exists');
  } else {
    console.log('CREATE idx_health_records_patient_created ON health_records(patient_id, created_at)');
    await addIndex('health_records', 'idx_health_records_patient_created', '`patient_id`, `created_at`');
    console.log('  ✓ created');
  }

  // ── 3. appointments(patient_id, appointment_date) ────────────────────────
  if (await indexExists('appointments', 'idx_appointments_patient_date')) {
    console.log('SKIP  idx_appointments_patient_date — already exists');
  } else {
    console.log('CREATE idx_appointments_patient_date ON appointments(patient_id, appointment_date)');
    await addIndex('appointments', 'idx_appointments_patient_date', '`patient_id`, `appointment_date`');
    console.log('  ✓ created');
  }

  await conn.end();
  console.log('\nMigration 003 complete.');
}

run()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('\nMigration FAILED:', err.sqlMessage || err.message);
    process.exit(1);
  });
