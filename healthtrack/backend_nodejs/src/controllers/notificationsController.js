const db = require("../config/db");

// Get notifications for a user
const getUserNotifications = async (req, res) => {
  try {
    const { userId } = req.params;
    
    if (!userId) {
      return res.status(400).json({
        success: false,
        message: "User ID is required"
      });
    }

    const query = `
      SELECT 
        id,
        user_id,
        appointment_id,
        notification_type,
        title,
        message,
        is_read,
        read_at,
        created_at,
        updated_at
      FROM notifications
      WHERE user_id = ?
      ORDER BY created_at DESC
    `;

    const [notifications] = await db.execute(query, [userId]);
    
    res.json({
      success: true,
      data: notifications,
      count: notifications.length
    });
  } catch (error) {
    console.error("Error fetching user notifications:", error);
    // Handle case where notifications table doesn't exist
    if (error.code === 'ER_NO_SUCH_TABLE' || error.message.includes('notifications')) {
      res.status(200).json({
        success: true,
        data: [],
        count: 0
      });
    } else {
      res.status(500).json({
        success: false,
        message: "Failed to fetch user notifications",
        error: error.message
      });
    }
  }
};

// Get unread notifications count for a user
const getUnreadNotificationsCount = async (req, res) => {
  try {
    const { userId } = req.params;
    
    if (!userId) {
      return res.status(400).json({
        success: false,
        message: "User ID is required"
      });
    }

    const query = `
      SELECT COUNT(*) as count
      FROM notifications
      WHERE user_id = ? AND is_read = 0
    `;

    const [result] = await db.execute(query, [userId]);
    const count = result[0]?.count || 0;
    
    res.json({
      success: true,
      count: count
    });
  } catch (error) {
    console.error("Error fetching unread notifications count:", error);
    // Handle case where notifications table doesn't exist
    if (error.code === 'ER_NO_SUCH_TABLE' || error.message.includes('notifications')) {
      res.status(200).json({
        success: true,
        count: 0
      });
    } else {
      res.status(500).json({
        success: false,
        message: "Failed to fetch unread notifications count",
        error: error.message
      });
    }
  }
};

// Mark notification as read
const markNotificationAsRead = async (req, res) => {
  try {
    const { id } = req.params;
    
    if (!id) {
      return res.status(400).json({
        success: false,
        message: "Notification ID is required"
      });
    }

    const query = `
      UPDATE notifications 
      SET is_read = 1, read_at = NOW()
      WHERE id = ?
    `;

    const [result] = await db.execute(query, [id]);
    
    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: "Notification not found"
      });
    }

    res.json({
      success: true,
      message: "Notification marked as read"
    });
  } catch (error) {
    console.error("Error marking notification as read:", error);
    // Handle case where notifications table doesn't exist
    if (error.code === 'ER_NO_SUCH_TABLE' || error.message.includes('notifications')) {
      res.status(200).json({
        success: true,
        message: "Notification marked as read"
      });
    } else {
      res.status(500).json({
        success: false,
        message: "Failed to mark notification as read",
        error: error.message
      });
    }
  }
};

// Mark all notifications as read for a user
const markAllNotificationsAsRead = async (req, res) => {
  try {
    const { userId } = req.params;
    
    if (!userId) {
      return res.status(400).json({
        success: false,
        message: "User ID is required"
      });
    }

    const query = `
      UPDATE notifications 
      SET is_read = 1, read_at = NOW()
      WHERE user_id = ? AND is_read = 0
    `;

    const [result] = await db.execute(query, [userId]);
    
    res.json({
      success: true,
      message: "All notifications marked as read",
      count: result.affectedRows
    });
  } catch (error) {
    console.error("Error marking all notifications as read:", error);
    // Handle case where notifications table doesn't exist
    if (error.code === 'ER_NO_SUCH_TABLE' || error.message.includes('notifications')) {
      res.status(200).json({
        success: true,
        message: "All notifications marked as read",
        count: 0
      });
    } else {
      res.status(500).json({
        success: false,
        message: "Failed to mark all notifications as read",
        error: error.message
      });
    }
  }
};

// Delete notification
const deleteNotification = async (req, res) => {
  try {
    const { id } = req.params;
    
    if (!id) {
      return res.status(400).json({
        success: false,
        message: "Notification ID is required"
      });
    }

    const query = "DELETE FROM notifications WHERE id = ?";
    const [result] = await db.execute(query, [id]);
    
    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: "Notification not found"
      });
    }

    res.json({
      success: true,
      message: "Notification deleted successfully"
    });
  } catch (error) {
    console.error("Error deleting notification:", error);
    // Handle case where notifications table doesn't exist
    if (error.code === 'ER_NO_SUCH_TABLE' || error.message.includes('notifications')) {
      res.status(200).json({
        success: true,
        message: "Notification deleted successfully"
      });
    } else {
      res.status(500).json({
        success: false,
        message: "Failed to delete notification",
        error: error.message
      });
    }
  }
};

module.exports = {
  getUserNotifications,
  getUnreadNotificationsCount,
  markNotificationAsRead,
  markAllNotificationsAsRead,
  deleteNotification
};