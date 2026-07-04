import 'dart:convert';
import 'package:flutter/material.dart'
    show
        BuildContext,
        Colors,
        ScaffoldMessenger,
        SnackBar,
        SnackBarBehavior,
        Text;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'api_config.dart';
import 'user_session_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VaccineCardPdfData
// ─────────────────────────────────────────────────────────────────────────────

/// All data needed to render a DOH-format vaccine card PDF.
/// Populated from the /vaccines/card/:id or /vaccines/admin/card/:id response
/// plus clinic info from /system-settings/public/clinic.
class VaccineCardPdfData {
  final String childName;
  final String? dob;
  final String? sex;
  final String? motherName;
  final String? fatherName;
  final String? placeOfBirth;
  final String? address;
  final String? healthCenter;
  final bool dobNeedsVerification;
  final int patientId;
  final String displayPatientId;   // HC-2025-XXXX
  final String clinicName;
  final String clinicAddress;
  final List<VaccineGroupPdf> vaccines;

  const VaccineCardPdfData({
    required this.childName,
    this.dob,
    this.sex,
    this.motherName,
    this.fatherName,
    this.placeOfBirth,
    this.address,
    this.healthCenter,
    required this.dobNeedsVerification,
    required this.patientId,
    required this.displayPatientId,
    required this.clinicName,
    required this.clinicAddress,
    required this.vaccines,
  });
}

class VaccineGroupPdf {
  final String vaccineName;
  final String vaccineKey;
  final List<VaccineDosePdf> doses;

  const VaccineGroupPdf({
    required this.vaccineName,
    required this.vaccineKey,
    required this.doses,
  });
}

class VaccineDosePdf {
  final int doseNumber;
  final String doseLabel;
  final String? givenAt;   // ISO date string or null
  final String? givenBy;
  final String? remarks;

  const VaccineDosePdf({
    required this.doseNumber,
    required this.doseLabel,
    this.givenAt,
    this.givenBy,
    this.remarks,
  });

  bool get isCompleted => givenAt != null && givenAt!.isNotEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
// VaccineCardPdfService
// ─────────────────────────────────────────────────────────────────────────────

class VaccineCardPdfService {
  // ── Fetch clinic settings (public — no auth) ──────────────────────────────
  static Future<Map<String, String>> _fetchClinicInfo() async {
    try {
      final base = ApiConfig.baseUrl;
      final resp = await http
          .get(
            Uri.parse('$base/system-settings/public/clinic'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        if (body['success'] == true && body['data'] != null) {
          final d = body['data'] as Map<String, dynamic>;
          return {
            'clinic_name':    d['clinic_name']?.toString()    ?? 'HealthTrack Health Center',
            'clinic_address': d['clinic_address']?.toString() ?? '',
          };
        }
      }
    } catch (_) {}
    return {
      'clinic_name':    'HealthTrack Health Center',
      'clinic_address': '',
    };
  }

  // ── Fetch vaccine card from patient endpoint ──────────────────────────────
  static Future<VaccineCardPdfData> fetchForPatient(int patientId) async {
    final token = await UserSessionStorage.getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    Exception? last;
    for (final base in ApiConfig.fallbackBaseUrls) {
      try {
        final resp = await http
            .get(Uri.parse('$base/vaccines/card/$patientId'), headers: headers)
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final body = json.decode(resp.body) as Map<String, dynamic>;
          if (body['success'] == true) {
            final clinic = await _fetchClinicInfo();
            return _parseCardData(
              body['data'] as Map<String, dynamic>,
              patientId,
              clinic,
            );
          }
          last = Exception(body['message']?.toString() ?? 'Failed to load vaccine card');
        } else {
          last = Exception('HTTP ${resp.statusCode}');
        }
      } catch (e) {
        last = Exception('$e');
      }
    }
    throw last ?? Exception('Failed to load vaccine card');
  }

  // ── Fetch vaccine card from admin endpoint ────────────────────────────────
  static Future<VaccineCardPdfData> fetchForAdmin({
    required int patientId,
    required Future<String?> Function() getAdminToken,
  }) async {
    final token = await getAdminToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final base = ApiConfig.baseUrl;
    final resp = await http
        .get(Uri.parse('$base/vaccines/admin/card/$patientId'), headers: headers)
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final body = json.decode(resp.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(body['message']?.toString() ?? 'Failed to load vaccine card');
    }
    final clinic = await _fetchClinicInfo();
    return _parseCardData(
      body['data'] as Map<String, dynamic>,
      patientId,
      clinic,
    );
  }

  // ── Parse API response into VaccineCardPdfData ────────────────────────────
  static VaccineCardPdfData _parseCardData(
    Map<String, dynamic> data,
    int patientId,
    Map<String, String> clinic,
  ) {
    final rawVaccines = (data['vaccines'] as List?) ?? [];
    final vaccines = rawVaccines.map((v) {
      final vMap = v as Map<String, dynamic>;
      final rawDoses = (vMap['doses'] as List?) ?? [];
      final doses = rawDoses.map((d) {
        final dMap = d as Map<String, dynamic>;
        return VaccineDosePdf(
          doseNumber: (dMap['dose_number'] as num?)?.toInt() ?? 1,
          doseLabel:  dMap['dose_label']?.toString() ?? '',
          givenAt:    dMap['given_at']?.toString(),
          givenBy:    dMap['given_by']?.toString(),
          remarks:    dMap['remarks']?.toString(),
        );
      }).toList();
      return VaccineGroupPdf(
        vaccineName: vMap['vaccine_name']?.toString() ?? '',
        vaccineKey:  vMap['vaccine_key']?.toString() ?? '',
        doses: doses,
      );
    }).toList();

    final displayId = 'HC-2025-${patientId.toString().padLeft(4, '0')}';

    return VaccineCardPdfData(
      childName:            data['child_name']?.toString()    ?? 'Unknown',
      dob:                  data['dob']?.toString(),
      sex:                  data['sex']?.toString(),
      motherName:           data['mother_name']?.toString(),
      fatherName:           data['father_name']?.toString(),
      placeOfBirth:         data['place_of_birth']?.toString(),
      address:              data['address']?.toString(),
      healthCenter:         data['health_center']?.toString(),
      dobNeedsVerification: data['dob_needs_verification'] == true ||
                            data['dob_needs_verification'] == 1,
      patientId:            patientId,
      displayPatientId:     displayId,
      clinicName:           clinic['clinic_name']    ?? 'HealthTrack Health Center',
      clinicAddress:        clinic['clinic_address'] ?? '',
      vaccines:             vaccines,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PDF Document Builder
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates the DOH-format vaccine card as a pw.Document.
  static pw.Document buildPdf(VaccineCardPdfData data) {
    final pdf = pw.Document(
      title: 'Child Immunization Card — ${data.childName}',
      author: data.clinicName,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        build: (pw.Context ctx) => [
          _buildHeader(data),
          pw.SizedBox(height: 10),
          _buildChildInfoTable(data),
          pw.SizedBox(height: 12),
          _buildVaccineTable(data),
          pw.SizedBox(height: 10),
          if (data.dobNeedsVerification) ...[
            _buildDobWarningNote(),
            pw.SizedBox(height: 8),
          ],
          _buildFooter(data),
        ],
      ),
    );

    return pdf;
  }

  // ── Header ────────────────────────────────────────────────────────────────
  static pw.Widget _buildHeader(VaccineCardPdfData data) {
    final now = DateTime.now();
    final genDate = DateFormat('MM/dd/yyyy hh:mm a').format(now);

    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 1.5, color: PdfColors.blueGrey700),
        ),
      ),
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Republic of Philippines line
          pw.Text(
            'Republic of the Philippines',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.Text(
            'Department of Health',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.blueGrey700,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'CHILD IMMUNIZATION CARD',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
              letterSpacing: 1.2,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'HealthTrack Digital Record',
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.blueGrey600,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 6),
          // Clinic info + generation date row
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    data.clinicName,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  if (data.clinicAddress.isNotEmpty)
                    pw.Text(
                      data.clinicAddress,
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.blueGrey600,
                      ),
                    ),
                ],
              ),
              pw.Text(
                'Generated on: $genDate',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.blueGrey600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Child Info Table ───────────────────────────────────────────────────────
  static pw.Widget _buildChildInfoTable(VaccineCardPdfData data) {
    final dobFormatted = _fmtDate(data.dob);

    pw.Widget infoRow(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.isNotEmpty ? value : '—',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey900),
            ),
          ),
        ],
      ),
    );

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey300, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: PdfColors.grey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PATIENT INFORMATION',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey700,
              letterSpacing: 0.8,
            ),
          ),
          pw.Divider(height: 8, thickness: 0.5, color: PdfColors.blueGrey300),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    infoRow("Child's Full Name", data.childName),
                    infoRow('Date of Birth', dobFormatted),
                    infoRow('Sex', data.sex ?? '—'),
                    infoRow('Place of Birth', data.placeOfBirth ?? '—'),
                    infoRow('Address', data.address ?? '—'),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    infoRow("Mother's Name", data.motherName ?? '—'),
                    infoRow("Father's Name", data.fatherName ?? '—'),
                    infoRow('Health Center', data.healthCenter ?? '—'),
                    infoRow('Patient ID', data.displayPatientId),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Vaccine Table ─────────────────────────────────────────────────────────
  static pw.Widget _buildVaccineTable(VaccineCardPdfData data) {
    // Header row style
    final headerStyle = pw.TextStyle(
      fontSize: 8.5,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final cellStyle = const pw.TextStyle(fontSize: 8.5, color: PdfColors.blueGrey900);
    final cellStyleGrey = const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey500);
    final headerBg = PdfColors.blueGrey700;

    pw.Widget hCell(String text) => pw.Container(
      color: headerBg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(text, style: headerStyle),
    );

    pw.Widget cell(String text, {bool grey = false, bool center = false}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: pw.Text(
            text,
            style: grey ? cellStyleGrey : cellStyle,
            textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
          ),
        );

    // Build rows — each vaccine group, each dose on its own row.
    final rows = <pw.TableRow>[
      // Header
      pw.TableRow(
        children: [
          hCell('Vaccine'),
          hCell('Dose'),
          hCell('Date Given'),
          hCell('Given By'),
          hCell('Remarks'),
        ],
      ),
    ];

    // Alternate row shading
    var rowIndex = 0;
    for (final group in data.vaccines) {
      for (final dose in group.doses) {
        final isShaded = rowIndex.isEven;
        final bg = isShaded ? PdfColors.grey100 : PdfColors.white;

        final dateText = dose.isCompleted ? _fmtDate(dose.givenAt!) : '';
        final givenByText = (dose.givenBy != null && dose.givenBy!.isNotEmpty)
            ? dose.givenBy!
            : '';
        final remarksText = (dose.remarks != null && dose.remarks!.isNotEmpty)
            ? dose.remarks!
            : '';

        // Show full vaccine name only on first dose of the group, abbreviated thereafter
        final vaccineLabel = dose.doseNumber == 1
            ? group.vaccineName
            : '';  // blank — visually groups the doses under the vaccine name

        rows.add(
          pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                child: pw.Text(
                  vaccineLabel,
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: dose.doseNumber == 1
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                    color: PdfColors.blueGrey900,
                  ),
                ),
              ),
              cell(dose.doseLabel, center: true),
              cell(dateText),
              cell(givenByText, grey: givenByText.isEmpty),
              cell(remarksText, grey: remarksText.isEmpty),
            ],
          ),
        );
        rowIndex++;
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'IMMUNIZATION RECORD',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey700,
            letterSpacing: 0.8,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Table(
          border: pw.TableBorder.all(
            color: PdfColors.blueGrey300,
            width: 0.5,
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(3.2),  // Vaccine name — widest
            1: const pw.FlexColumnWidth(1.4),  // Dose
            2: const pw.FlexColumnWidth(1.8),  // Date Given
            3: const pw.FlexColumnWidth(2.8),  // Given By
            4: const pw.FlexColumnWidth(2.0),  // Remarks
          },
          children: rows,
        ),
      ],
    );
  }

  // ── DOB verification note ─────────────────────────────────────────────────
  static pw.Widget _buildDobWarningNote() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.orange700, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        color: PdfColors.orange50,
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '⚠ ',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.orange800,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              "Note: This child's date of birth is pending verification. "
              "Vaccine schedule dates may not be accurate. "
              "Please contact the clinic to verify and correct the date of birth.",
              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.orange900),
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  static pw.Widget _buildFooter(VaccineCardPdfData data) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(width: 0.5, color: PdfColors.blueGrey300),
        ),
      ),
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'This is an official digital immunization record generated from HealthTrack. '
            'For verification, contact ${data.clinicName}.',
            style: const pw.TextStyle(
              fontSize: 7.5,
              color: PdfColors.blueGrey600,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'This digital record supplements but does not replace the official physical '
            'DOH Child Immunization Card (yellow card).',
            style: pw.TextStyle(
              fontSize: 7.5,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.blueGrey500,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Public entry points — print / download
  // ─────────────────────────────────────────────────────────────────────────

  /// Print / share the vaccine card. Shows a loading SnackBar while generating.
  /// [fetchData] is a callback that retrieves [VaccineCardPdfData] —
  /// pass either [fetchForPatient] or [fetchForAdmin] depending on context.
  ///
  /// Returns true on success, false on failure.
  static Future<bool> generateAndPrint({
    required Future<VaccineCardPdfData> Function() fetchData,
    BuildContext? context,
  }) async {
    try {
      final data  = await fetchData();
      final pdf   = buildPdf(data);
      final bytes = await pdf.save();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'VaccineCard_${data.childName.replaceAll(' ', '_')}_'
              '${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
      return true;
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to generate vaccine card. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Format ISO date string as MM/DD/YYYY (DOH card standard).
  static String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      return DateFormat('MM/dd/yyyy').format(d);
    } catch (_) {
      return raw;
    }
  }
}
