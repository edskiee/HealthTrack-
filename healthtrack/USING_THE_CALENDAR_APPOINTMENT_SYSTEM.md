# Using the Calendar-First Appointment System

This guide explains how to use the new calendar-first appointment system in HealthTrack.

## For Users

### Accessing the Appointment System
1. Open the HealthTrack mobile app
2. Navigate to the "Appointments" tab in the bottom navigation bar
3. You'll see a full calendar view by default

### Booking an Appointment
1. Look for dates marked with blue dots - these indicate available slots
2. Tap on any date with available slots
3. A modal sheet will appear showing available time slots for that date
4. Select a time slot by tapping on it
5. Tap "Book Selected Slot" to confirm your appointment
6. You'll receive an instant confirmation notification
7. The slot will immediately become unavailable to other users

### Viewing Upcoming Appointments
- Scroll down below the calendar to see your upcoming appointments
- Appointments are sorted chronologically
- Appointment status is clearly indicated (Approved, Completed, Cancelled, etc.)

## For Administrators

### Accessing Slot Management
1. Log into the HealthTrack admin panel
2. Navigate to "Administrative Tools"
3. Look for the "Slot Management" section with the calendar interface

### Managing Appointment Slots
1. Use the calendar view to see existing slots (marked with blue dots)
2. Tap on any date to view or modify existing slots for that date
3. Use the dropdown to select which service type you're configuring (Immunization or Maternal Care)

### Creating New Slots
#### Single Slot Creation:
1. Tap on a date in the calendar
2. In the modal sheet, scroll to the "Add New Slot" section
3. Set the start time, end time, slot duration, and maximum patients
4. Toggle slot availability as needed
5. Tap "Create Slot"

#### Bulk Slot Creation:
1. Tap the "Quick Actions" button
2. Select "Create Bulk Slots"
3. Set the date range, time range, interval, and patients per slot
4. Tap "Create Slots" to generate multiple slots at once

### Editing Existing Slots
1. Tap on a date with existing slots
2. Find the slot you want to edit in the "Existing Slots" list
3. Tap the menu icon (three dots) next to the slot
4. Select "Edit"
5. Modify the slot details as needed
6. Tap "Update Slot"

### Deleting Slots
1. Tap on a date with existing slots
2. Find the slot you want to delete in the "Existing Slots" list
3. Tap the menu icon (three dots) next to the slot
4. Select "Delete"
5. Confirm the deletion in the dialog

## Key Features

### Real-Time Synchronization
- Changes made by administrators are instantly reflected in the user calendar
- No manual refresh needed - the system updates automatically
- Prevents double bookings by immediately marking slots as unavailable

### Visual Indicators
- Blue dots on calendar dates indicate available slots
- Orange circle highlights today's date
- Selected dates are highlighted in blue

### Automatic Slot Generation
- System automatically generates time slots based on administrator configuration
- 30-minute intervals with 10-minute breaks between sessions
- Configurable capacity per time slot

### Instant Confirmation
- Users receive real-time push notifications when appointments are confirmed
- Appointments with valid slots are automatically approved
- No manual approval process needed

## Best Practices

### For Administrators
1. Configure slots in advance to give users maximum booking flexibility
2. Use bulk slot creation for regular schedules (e.g., weekly recurring slots)
3. Monitor slot utilization to optimize availability
4. Communicate any schedule changes promptly to users

### For Users
1. Book appointments early for popular time slots
2. Check the calendar regularly for newly added slots
3. Cancel appointments as early as possible to allow others to book
4. Keep notifications enabled to receive confirmation alerts

## Troubleshooting

### Calendar Not Updating
- Ensure you have a stable internet connection
- Try pulling down to refresh the calendar view
- Restart the app if issues persist

### Unable to Book Slot
- Verify the slot is still available (blue dot on calendar)
- Check that you're logged in to your account
- Contact support if you believe this is an error

### Not Receiving Notifications
- Check that notifications are enabled in your device settings
- Verify that your account has a valid FCM token
- Ensure the HealthTrack app has notification permissions

---

*MOTO: "Smart Scheduling for Safer, Faster, and More Reliable Healthcare Access."*