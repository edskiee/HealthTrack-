const db = require('../config/db');

// Create a new referral
exports.createReferral = async (req, res) => {
  try {
    const { patient_id, referred_to, referral_date, referral_notes, referring_admin_id } = req.body;

    // Validation
    if (!patient_id || !referred_to || !referral_date || !referral_notes) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: patient_id, referred_to, referral_date, referral_notes'
      });
    }

    // Validate referral notes length (minimum 10 characters)
    if (referral_notes.trim().length < 10) {
      return res.status(400).json({
        success: false,
        message: 'Referral notes must be at least 10 characters long'
      });
    }

    // Check if patient exists
    const patientCheck = await db.query(
      'SELECT id, patientName FROM patients WHERE id = ?',
      [patient_id]
    );

    if (patientCheck.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Patient not found'
      });
    }

    // Create referral
    const result = await db.query(
      `INSERT INTO referrals (patient_id, referred_to, referral_date, referral_notes, referring_admin_id) 
       VALUES (?, ?, ?, ?, ?)`,
      [patient_id, referred_to, referral_date, referral_notes.trim(), referring_admin_id || null]
    );

    const newReferral = {
      id: result.insertId,
      patient_id,
      referred_to,
      referral_date,
      referral_notes: referral_notes.trim(),
      referring_admin_id: referring_admin_id || null,
      status: 'pending',
      created_at: new Date().toISOString()
    };

    // Emit real-time update to user's room
    const io = req.app.locals.io;
    if (io) {
      io.to(`user_${patient_id}`).emit('newReferral', {
        type: 'referral_created',
        data: newReferral,
        patient_name: patientCheck[0].patientName,
        message: `New referral created: ${referred_to}`
      });
    }

    res.status(201).json({
      success: true,
      message: 'Referral created successfully',
      data: newReferral
    });

  } catch (error) {
    console.error('Error creating referral:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
};

// Get referrals for a specific patient
exports.getPatientReferrals = async (req, res) => {
  try {
    const { patient_id } = req.params;

    if (!patient_id) {
      return res.status(400).json({
        success: false,
        message: 'Patient ID is required'
      });
    }

    const referrals = await db.query(
      `SELECT r.*, 
              p.patientName,
              a.username as admin_name
       FROM referrals r
       LEFT JOIN patients p ON r.patient_id = p.id
       LEFT JOIN admins a ON r.referring_admin_id = a.id
       WHERE r.patient_id = ?
       ORDER BY r.created_at DESC`,
      [patient_id]
    );

    res.status(200).json({
      success: true,
      message: 'Referrals retrieved successfully',
      data: referrals
    });

  } catch (error) {
    console.error('Error fetching patient referrals:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
};

// Get all referrals (for admin)
exports.getAllReferrals = async (req, res) => {
  try {
    const referrals = await db.query(
      `SELECT r.*, 
              p.patientName,
              a.username as admin_name
       FROM referrals r
       LEFT JOIN patients p ON r.patient_id = p.id
       LEFT JOIN admins a ON r.referring_admin_id = a.id
       ORDER BY r.created_at DESC`
    );

    res.status(200).json({
      success: true,
      message: 'All referrals retrieved successfully',
      data: referrals
    });

  } catch (error) {
    console.error('Error fetching all referrals:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
};

// Update referral status
exports.updateReferralStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!id || !status) {
      return res.status(400).json({
        success: false,
        message: 'Referral ID and status are required'
      });
    }

    const validStatuses = ['pending', 'accepted', 'completed', 'cancelled'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid status. Must be one of: ' + validStatuses.join(', ')
      });
    }

    // Check if referral exists and get patient_id
    const existingReferral = await db.query(
      'SELECT patient_id, referred_to FROM referrals WHERE id = ?',
      [id]
    );

    if (existingReferral.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Referral not found'
      });
    }

    // Update referral
    await db.query(
      'UPDATE referrals SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [status, id]
    );

    // Emit real-time update to user's room
    const io = req.app.locals.io;
    if (io) {
      io.to(`user_${existingReferral[0].patient_id}`).emit('referralStatusUpdated', {
        type: 'referral_status_updated',
        referral_id: parseInt(id),
        new_status: status,
        referred_to: existingReferral[0].referred_to,
        message: `Referral status updated to: ${status}`
      });
    }

    res.status(200).json({
      success: true,
      message: 'Referral status updated successfully',
      data: {
        id: parseInt(id),
        status,
        updated_at: new Date().toISOString()
      }
    });

  } catch (error) {
    console.error('Error updating referral status:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
};

// Delete a referral
exports.deleteReferral = async (req, res) => {
  try {
    const { id } = req.params;

    if (!id) {
      return res.status(400).json({
        success: false,
        message: 'Referral ID is required'
      });
    }

    // Check if referral exists and get patient_id
    const existingReferral = await db.query(
      'SELECT patient_id, referred_to FROM referrals WHERE id = ?',
      [id]
    );

    if (existingReferral.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Referral not found'
      });
    }

    // Delete referral
    await db.query('DELETE FROM referrals WHERE id = ?', [id]);

    // Emit real-time update to user's room
    const io = req.app.locals.io;
    if (io) {
      io.to(`user_${existingReferral[0].patient_id}`).emit('referralDeleted', {
        type: 'referral_deleted',
        referral_id: parseInt(id),
        referred_to: existingReferral[0].referred_to,
        message: `Referral to ${existingReferral[0].referred_to} has been deleted`
      });
    }

    res.status(200).json({
      success: true,
      message: 'Referral deleted successfully'
    });

  } catch (error) {
    console.error('Error deleting referral:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
};
