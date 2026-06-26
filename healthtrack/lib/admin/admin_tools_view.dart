import 'package:flutter/material.dart';
import 'package:healthtrack/admin/widgets/enhanced_slot_management_calendar.dart';
import 'package:healthtrack/admin/widgets/slot_configuration_panel.dart';
import '../services/service_config_service.dart';
import '../models/service_model.dart';
import '../utils/message_utils.dart';
import 'widgets/admin_header.dart';

class AdminToolsView extends StatefulWidget {
  const AdminToolsView({super.key});

  @override
  State<AdminToolsView> createState() => _AdminToolsViewState();
}

class _AdminToolsViewState extends State<AdminToolsView> {
  bool _showConfigPanel = false;
  DateTime? _selectedDate;
  List<ServiceModel> _services = [];
  int? _selectedServiceId;
  bool _isLoadingServices = true;
  int _calendarRefreshTrigger = 0;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() {
      _isLoadingServices = true;
    });

    try {
      final filteredServices = await ServiceConfigService.getAppointmentServices();

      if (mounted) {
        setState(() {
          _services = filteredServices;
          _selectedServiceId = ServiceConfigService.resolveSelectedServiceId(
            _services,
            _selectedServiceId,
          );
          _isLoadingServices = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingServices = false;
        });
        MessageUtils.showErrorMessage(context, "Failed to load services: $e");
      }
    }
  }

  void _triggerCalendarRefresh() {
    setState(() {
      _calendarRefreshTrigger++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: Column(
        children: [
          AdminHeader(
            title: "Administrative Tools",
            subtitle: "Manage appointment slots and system configurations",
            onRefresh: () async {
              await _loadServices();
              _triggerCalendarRefresh();
            },
            showLiveClock: true,
          ),
          
          // Main content area
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side: Calendar (takes most space)
                    Expanded(
                      flex: _showConfigPanel ? 2 : 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Appointment Slot Management",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: EnhancedSlotManagementCalendar(
                                  services: _services,
                                  selectedServiceId: _selectedServiceId,
                                  isLoadingServices: _isLoadingServices,
                                  onServiceSelected: (serviceId) {
                                    setState(() {
                                      _selectedServiceId = serviceId;
                                    });
                                  },
                                  refreshTrigger: _calendarRefreshTrigger,
                                  onSlotsUpdated: () {
                                    // Refresh the UI if needed
                                  },
                                  onDateSelected: (selectedDate) {
                                    setState(() {
                                      _showConfigPanel = true;
                                      _selectedDate = selectedDate;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    if (_showConfigPanel && _selectedDate != null) ...[
                      const SizedBox(width: 24),
                      
                      // Right side: Professional Slot Configuration Panel
                      Expanded(
                        flex: 1,
                        child: SlotConfigurationPanel(
                          selectedDate: _selectedDate!,
                          services: _services,
                          selectedServiceId: _selectedServiceId,
                          onSlotsGenerated: () {
                            // Force an immediate calendar re-fetch after successful generation.
                            _triggerCalendarRefresh();
                            setState(() {
                              _showConfigPanel = false;
                              _selectedDate = null;
                            });
                          },
                          onClose: () {
                            setState(() {
                              _showConfigPanel = false;
                              _selectedDate = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
