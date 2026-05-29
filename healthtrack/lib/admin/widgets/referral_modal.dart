import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/referral_service.dart';
import '../../utils/message_utils.dart';

class ReferralModal extends StatefulWidget {
  final int patientId;
  final String patientName;
  final VoidCallback onReferralCreated;

  const ReferralModal({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.onReferralCreated,
  });

  @override
  State<ReferralModal> createState() => _ReferralModalState();
}

class _ReferralModalState extends State<ReferralModal> {
  final _formKey = GlobalKey<FormState>();
  final _referredToController = TextEditingController();
  final _referralNotesController = TextEditingController();
  DateTime? _selectedDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _referredToController.dispose();
    _referralNotesController.dispose();
    super.dispose();
  }

  Future<void> _submitReferral() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final referral = await ReferralService.createReferral(
        patientId: widget.patientId,
        referredTo: _referredToController.text.trim(),
        referralDate: DateFormat('yyyy-MM-dd').format(_selectedDate!),
        referralNotes: _referralNotesController.text.trim(),
      );

      if (referral != null) {
        widget.onReferralCreated();
        if (mounted) {
          Navigator.of(context).pop();
          MessageUtils.showSuccessMessage(
            context,
            'Referral created successfully for ${widget.patientName}',
            title: "Success",
          );
        }
      }
    } catch (e) {
      if (mounted) {
        MessageUtils.showErrorMessage(
          context,
          'Failed to create referral: $e',
          title: "Error",
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Create Referral",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Patient: ${widget.patientName}",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Referred To Field
                      TextFormField(
                        controller: _referredToController,
                        decoration: InputDecoration(
                          labelText: "Referred To *",
                          hintText: "Hospital, clinic, or doctor name",
                          prefixIcon: const Icon(Icons.local_hospital, color: Color(0xFF6B7280)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter where the patient is being referred to';
                          }
                          if (value.trim().length < 3) {
                            return 'Must be at least 3 characters long';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 20),

                      // Referral Date Field
                      InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xFFF9FAFB),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Color(0xFF6B7280)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedDate != null
                                      ? DateFormat('MMMM dd, yyyy').format(_selectedDate!)
                                      : "Select referral date *",
                                  style: TextStyle(
                                    color: _selectedDate != null
                                        ? const Color(0xFF1F2937)
                                        : const Color(0xFF6B7280),
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: Color(0xFF6B7280)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Referral Notes Field
                      TextFormField(
                        controller: _referralNotesController,
                        decoration: InputDecoration(
                          labelText: "Referral Notes *",
                          hintText: "Enter detailed clinical notes and reason for referral...",
                          prefixIcon: const Icon(Icons.notes, color: Color(0xFF6B7280)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 5,
                        minLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter referral notes';
                          }
                          if (value.trim().length < 10) {
                            return 'Notes must be at least 10 characters long';
                          }
                          if (value.trim().length > 1000) {
                            return 'Notes must not exceed 1000 characters';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submitReferral(),
                      ),
                      const SizedBox(height: 16),

                      // Character count for notes
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "${_referralNotesController.text.length}/1000 characters",
                          style: TextStyle(
                            color: _referralNotesController.text.length > 1000
                                ? Colors.red
                                : const Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReferral,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: const Color(0xFF9CA3AF),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            "Create Referral",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
