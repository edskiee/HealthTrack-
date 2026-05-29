const db = require("../config/db");

async function ensureAdminPreferences(adminId) {
  const insert = () =>
    db.execute(
      `INSERT IGNORE INTO admin_preferences (admin_id) VALUES (?)`,
      [adminId]
    );

  try {
    await insert();
  } catch (err) {
    const missingTable =
      err &&
      (err.code === "ER_NO_SUCH_TABLE" ||
        (typeof err.message === "string" &&
          err.message.includes("admin_preferences")));
    if (missingTable) {
      try {
        const initAdminTables = require("./initAdminTables");
        await initAdminTables();
        await insert();
        return;
      } catch (retryErr) {
        console.error("[ensureAdminPreferences] error:", retryErr);
        throw retryErr;
      }
    }
    console.error("[ensureAdminPreferences] error:", err);
    throw err;
  }
}

module.exports = { ensureAdminPreferences };
