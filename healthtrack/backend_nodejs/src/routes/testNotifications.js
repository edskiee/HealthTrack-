const express = require("express");
const db = require("../config/db");
const { sendToUserDevices } = require("../services/appointmentPushService");

const router = express.Router();

async function getAppointmentById(appointmentId) {
  const [rows] = await db.execute(
    `SELECT id, user_id, appointment_date, appointment_time, appointment_type, status
     FROM appointments WHERE id = ?`,
    [appointmentId]
  );
  return rows[0] || null;
}

router.post("/notify/approved", async (req, res) => {
  try {
    const appointmentId = Number.parseInt(String(req.body.appointmentId), 10);
    const appointment = await getAppointmentById(appointmentId);
    if (!appointment) return res.status(404).json({ success: false, message: "Appointment not found" });

    const result = await sendToUserDevices(
      appointment.user_id,
      "appointment_approved",
      "Appointment Approved",
      `Your appointment on ${appointment.appointment_date} ${appointment.appointment_time} is confirmed`,
      {
        appointmentId: appointment.id,
        appointmentDate: appointment.appointment_date,
        appointmentTime: appointment.appointment_time,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      `test:approval:${appointment.id}:${appointment.appointment_date}:${appointment.appointment_time}`
    );
    res.json({ success: true, result });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.post("/notify/rescheduled", async (req, res) => {
  try {
    const appointmentId = Number.parseInt(String(req.body.appointmentId), 10);
    const appointment = await getAppointmentById(appointmentId);
    if (!appointment) return res.status(404).json({ success: false, message: "Appointment not found" });

    const date = req.body.rescheduleDate || appointment.appointment_date;
    const time = req.body.rescheduleTime || appointment.appointment_time;
    const result = await sendToUserDevices(
      appointment.user_id,
      "appointment_rescheduled",
      "Appointment Rescheduled",
      `Your appointment has been moved to ${date} ${time}.`,
      {
        appointmentId: appointment.id,
        appointmentDate: date,
        appointmentTime: time,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      `test:reschedule:${appointment.id}:${date}:${time}`
    );
    res.json({ success: true, result });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.post("/notify/reminder", async (req, res) => {
  try {
    const appointmentId = Number.parseInt(String(req.body.appointmentId), 10);
    const appointment = await getAppointmentById(appointmentId);
    if (!appointment) return res.status(404).json({ success: false, message: "Appointment not found" });

    const result = await sendToUserDevices(
      appointment.user_id,
      "appointment_reminder",
      "Appointment Reminder",
      `Reminder: your appointment is on ${appointment.appointment_date} at ${appointment.appointment_time}.`,
      {
        appointmentId: appointment.id,
        appointmentDate: appointment.appointment_date,
        appointmentTime: appointment.appointment_time,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      `test:reminder:${appointment.id}`
    );
    res.json({ success: true, result });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
