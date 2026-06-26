import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/service_model.dart';
import 'api_config.dart';

class ServiceConfigService {
  static String get baseUrl => ApiConfig.baseUrl;
  static List<String> get fallbackBaseUrls => ApiConfig.fallbackBaseUrls;

  /// Immunization + Maternal Care services used by admin slot tools and booking.
  static Future<List<ServiceModel>> getAppointmentServices() async {
    final raw = await getAllServices();
    final models = raw.map(ServiceModel.fromJson).toList();
    final filtered = models.where(_isAppointmentService).toList()
      ..sort((a, b) => a.serviceName.compareTo(b.serviceName));
    return filtered;
  }

  static bool _isAppointmentService(ServiceModel service) {
    final type = service.serviceType.toLowerCase();
    if (type == 'immunization' || type == 'maternal') return true;
    final name = service.serviceName.trim().toLowerCase();
    return name == 'immunization' || name == 'maternal care';
  }

  /// Ensures [selectedId] exists in [services]; otherwise returns first id or null.
  static int? resolveSelectedServiceId(
    List<ServiceModel> services,
    int? selectedId,
  ) {
    if (services.isEmpty) return null;
    if (selectedId != null && services.any((s) => s.id == selectedId)) {
      return selectedId;
    }
    return services.first.id;
  }

  /// Get all active services
  static Future<List<Map<String, dynamic>>> getAllServices({String? serviceType}) async {
    Exception? lastException;
    
    for (final url in fallbackBaseUrls) {
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          String urlPath = "$url/service-config";
          if (serviceType != null) {
            urlPath += "?service_type=$serviceType";
          }

          final response = await http.get(
            Uri.parse(urlPath),
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['success'] == true) {
              return List<Map<String, dynamic>>.from(data['data'] ?? []);
            }
            lastException =
                Exception(data['message'] ?? 'Failed to fetch services');
          } else {
            lastException = Exception(
              "HTTP ${response.statusCode}: Failed to fetch services",
            );
          }
        } catch (e) {
          lastException = Exception("Failed to fetch services: $e");
        }

        if (attempt < 2) {
          await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
        }
      }
    }
    throw lastException ?? Exception("Failed to fetch services");
  }

  /// Get service by ID
  static Future<Map<String, dynamic>> getServiceById(int id) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse("$url/service-config/$id"),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            return data['data'];
          } else {
            lastException =
                Exception(data['message'] ?? 'Failed to fetch service');
          }
        } else {
          lastException =
              Exception("HTTP ${response.statusCode}: Failed to fetch service");
        }
      } catch (e) {
        lastException = Exception("Failed to fetch service: $e");
      }
    }
    throw lastException ?? Exception("Failed to fetch service");
  }
}