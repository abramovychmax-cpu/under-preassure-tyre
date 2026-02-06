import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches weather data from OpenWeatherMap API
/// Free tier: 1000 calls/day, update every 10 minutes per location
class WeatherService {
  // OpenWeatherMap API key - get yours at https://openweathermap.org/api
  // Free tier allows 1000 calls/day
  static const String _apiKey = 'YOUR_API_KEY_HERE'; // Replace with your key
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';
  
  double? lastTemperature; // Celsius
  double? lastAtmosphericPressure; // hPa (hectopascals/millibars)
  DateTime? lastUpdate;
  
  final Duration _updateInterval = const Duration(minutes: 10); // Stay within free tier limits
  
  /// Fetch weather data for given GPS coordinates
  Future<void> updateWeather(double lat, double lon) async {
    // Rate limiting: only update every 10 minutes
    if (lastUpdate != null && DateTime.now().difference(lastUpdate!) < _updateInterval) {
      return;
    }
    
    // Skip if no API key configured
    if (_apiKey == 'YOUR_API_KEY_HERE') {
      print('WeatherService: No API key configured, using defaults');
      lastTemperature = 20.0;
      lastAtmosphericPressure = 1013.25; // Standard atmospheric pressure at sea level
      return;
    }
    
    try {
      final url = Uri.parse('$_baseUrl?lat=$lat&lon=$lon&appid=$_apiKey&units=metric');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Extract temperature (already in Celsius due to units=metric)
        lastTemperature = (data['main']['temp'] as num?)?.toDouble();
        
        // Extract atmospheric pressure (hPa)
        lastAtmosphericPressure = (data['main']['pressure'] as num?)?.toDouble();
        
        lastUpdate = DateTime.now();
        print('Weather updated: ${lastTemperature?.toStringAsFixed(1)}°C, ${lastAtmosphericPressure?.toStringAsFixed(1)} hPa');
      } else {
        print('Weather API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Weather fetch failed: $e');
    }
  }
  
  /// Get temperature in Celsius, or default if unavailable
  int getTemperature() {
    return lastTemperature?.round() ?? 20;
  }
  
  /// Get atmospheric pressure in Pascals (FIT SDK uses Pascals, not hPa)
  /// OpenWeatherMap returns hPa (hectopascals), convert to Pa
  int getAtmosphericPressurePa() {
    if (lastAtmosphericPressure == null) return 101325; // Standard atmosphere
    return (lastAtmosphericPressure! * 100).round(); // hPa to Pa
  }
}
