const crypto = require("crypto");
const { UAParser } = require("ua-parser-js");

function summarizeUserAgent(userAgentHeader) {
  const p = new UAParser(userAgentHeader || "").getResult();
  const deviceBits = [];
  if (p.device?.type) deviceBits.push(p.device.type);
  if (p.device?.vendor) deviceBits.push(p.device.vendor);
  if (p.device?.model) deviceBits.push(p.device.model);
  const device = deviceBits.filter(Boolean).join(" ");
  const os = [p.os?.name, p.os?.version].filter(Boolean).join(" ");
  const browser = [p.browser?.name, p.browser?.version].filter(Boolean).join(" ");

  let deviceLabel = device || "Desktop / mobile device";
  if (os) {
    deviceLabel = `${deviceLabel} · ${os}`;
  }

  return {
    device_label: deviceLabel.slice(0, 128),
    browser_label: (browser || "Unknown browser").slice(0, 160),
    user_agent: userAgentHeader || null,
  };
}

/**
 * @returns {{ sessionId: string, tokenPlain: string }}
 */
async function createAdminSession(db, adminId, req) {
  const sessionId = crypto.randomUUID();
  const tokenPlain = crypto.randomUUID() + "." + crypto.randomBytes(24).toString("hex");
  const tokenHash = crypto.createHash("sha256").update(tokenPlain, "utf8").digest("hex");

  const { device_label, browser_label, user_agent } = summarizeUserAgent(
    typeof req?.get === "function" ? req.get("User-Agent") : ""
  );

  await db.execute(
    `INSERT INTO admin_sessions
      (id, admin_id, token_hash, user_agent, ip_address, device_label, browser_label)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      sessionId,
      adminId,
      tokenHash,
      user_agent,
      req?.ip ?? null,
      device_label,
      browser_label,
    ]
  );

  return { sessionId, tokenPlain };
}

module.exports = {
  summarizeUserAgent,
  createAdminSession,
};
