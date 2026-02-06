import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'protocol_selection_page.dart';
import 'ui/common_widgets.dart';

/// Wheel Metrics configuration page: wheel size, tire width, and unit preferences.
/// Appears right before sensor selection in the flow.
/// Uses light theme to match Protocol Selection and Coast Down pages.
class WheelMetricsPage extends StatefulWidget {
  const WheelMetricsPage({super.key});

  @override
  State<WheelMetricsPage> createState() => _WheelMetricsPageState();
}

class _WheelMetricsPageState extends State<WheelMetricsPage> {
  static const List<Map<String, dynamic>> wheelSizes = [
    // Road bike wheels (metric sizes)
    {'name': '700c', 'diameterMm': 622},
    {'name': '650b', 'diameterMm': 584},
    // Mountain bike wheels (inch sizes - standard)
    {'name': '29"', 'diameterMm': 622},
    {'name': '27.5"', 'diameterMm': 584},
    {'name': '26"', 'diameterMm': 559},
    // Smaller wheels
    {'name': '24"', 'diameterMm': 507},
    {'name': '20"', 'diameterMm': 406},
  ];

  late SharedPreferences _prefs;

  String _selectedWheelSize = '700c';
  int _selectedTireWidth = 28; // in mm
  String _selectedPressureUnit = 'PSI';
  String _selectedSpeedUnit = 'km/h';
  double _calculatedCircumference = 2.1;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    setState(() {
      _selectedWheelSize = _prefs.getString('wheel_size') ?? '700c';
      _selectedTireWidth = _prefs.getInt('tire_width') ?? 28;
      _selectedPressureUnit = _prefs.getString('pressure_unit') ?? 'PSI';
      _selectedSpeedUnit = _prefs.getString('speed_unit') ?? 'km/h';
      _calculatedCircumference = _prefs.getDouble('wheel_circumference') ?? 2.1;
      _isLoading = false;

      // Ensure tire width is in valid range
      if (_selectedTireWidth < 16) _selectedTireWidth = 16;
      if (_selectedTireWidth > 60) _selectedTireWidth = 60;
    });
  }

  void _calculateAndSaveCircumference() {
    final wheel = wheelSizes.firstWhere(
      (w) => w['name'] == _selectedWheelSize,
      orElse: () => {'diameterMm': 622},
    );

    final rimDiameterMm = wheel['diameterMm'] as int;
    final diameterM = (rimDiameterMm + 2 * _selectedTireWidth) / 1000;
    final circumferenceM = diameterM * 3.14159265359;

    setState(() {
      _calculatedCircumference = circumferenceM;
    });

    _prefs.setString('wheel_size', _selectedWheelSize);
    _prefs.setInt('tire_width', _selectedTireWidth);
    _prefs.setString('pressure_unit', _selectedPressureUnit);
    _prefs.setString('speed_unit', _selectedSpeedUnit);
    _prefs.setDouble('wheel_circumference', circumferenceM);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'WHEEL & TIRE SETUP',
          style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        foregroundColor: const Color(0xFF222222),
      ),
        body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentGemini))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wheel Size',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF222222),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorder, width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButton<String>(
                      value: _selectedWheelSize,
                      isExpanded: true,
                      underline: const SizedBox(),
                      style: const TextStyle(color: Color(0xFF222222), fontSize: 16, fontWeight: FontWeight.w500),
                      items: wheelSizes
                          .map((wheel) => DropdownMenuItem(
                                value: wheel['name'] as String,
                                child: Text(wheel['name'] as String),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedWheelSize = value);
                          _calculateAndSaveCircumference();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tire Width with slider (1mm increments)
                  const Text(
                    'Tire Width (mm)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF222222),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_selectedTireWidth mm',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF47D1C1),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _selectedTireWidth.toDouble(),
                    min: 16,
                    max: 60,
                    divisions: 44, // 16-60 = 44 increments = 1mm each
                    activeColor: const Color(0xFF47D1C1),
                    inactiveColor: cardBorder,
                    onChanged: (value) {
                      setState(() => _selectedTireWidth = value.toInt());
                    },
                    onChangeEnd: (_) {
                      _calculateAndSaveCircumference();
                    },
                  ),
                  const SizedBox(height: 24),

                  // Calculated circumference display
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorder, width: 1),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Wheel Circumference',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF666666),
                          ),
                        ),
                        Text(
                          '${_calculatedCircumference.toStringAsFixed(3)} m',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF222222),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Unit preferences
                  const Text(
                    'Unit Preferences',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF222222),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pressure',
                              style: TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: cardBorder, width: 1),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: DropdownButton<String>(
                                value: _selectedPressureUnit,
                                isExpanded: true,
                                underline: const SizedBox(),
                                style: const TextStyle(color: Color(0xFF222222), fontSize: 14, fontWeight: FontWeight.w500),
                                dropdownColor: Colors.white,
                                items: ['PSI', 'Bar']
                                    .map((unit) => DropdownMenuItem(
                                          value: unit,
                                          child: Text(unit, style: const TextStyle(color: Color(0xFF222222))),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedPressureUnit = value);
                                    _calculateAndSaveCircumference();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Speed',
                              style: TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: cardBorder, width: 1),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: DropdownButton<String>(
                                value: _selectedSpeedUnit,
                                isExpanded: true,
                                underline: const SizedBox(),
                                style: const TextStyle(color: Color(0xFF222222), fontSize: 14, fontWeight: FontWeight.w500),
                                dropdownColor: Colors.white,
                                items: ['km/h', 'miles']
                                    .map((unit) => DropdownMenuItem(
                                          value: unit,
                                          child: Text(unit, style: const TextStyle(color: Color(0xFF222222))),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedSpeedUnit = value);
                                    _calculateAndSaveCircumference();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF47D1C1),
                        foregroundColor: const Color(0xFFF2F2F2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProtocolSelectionPage()),
                        );
                      },
                      child: const Text(
                        'CONTINUE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
