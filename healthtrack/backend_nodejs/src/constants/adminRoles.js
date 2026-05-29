/**
 * Privileged backend roles accepted by Bearer admin session middleware.
 * Normalized lowercase for comparison against DB `admins.role`.
 */
const ADMIN_ROLES = ["admin", "administrator"];

module.exports = { ADMIN_ROLES };
