import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ui/common_widgets.dart';

/// Settings page for wheel size, tire width, and unit preferences.
/// Calculates wheel circumference based on standard tire sizes.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Wheel sizes (common cycling standards)
  static const List<Map<String, dynamic>> wheelSizes = [
    {'name': '700c', 'diameterMm': 622},
    {'name': '650b', 'diameterMm': 584},
    {'name': '26"', 'diameterMm': 559},
    {'name': '29"', 'diameterMm': 622},
    {'name': '27.5"', 'diameterMm': 584},
    {'name': '24"', 'diameterMm': 507},
  ];

  // Tire widths (common widths in mm)
  static const List<int> tireWidths = [
    18, 20, 23, 25, 28, 32, 35, 40, 45, 50, 60
  ];

  // Unit options
  static const List<String> pressureUnits = ['PSI', 'Bar'];
  static const List<String> speedUnits = ['km/h', 'miles'];

  late SharedPreferences _prefs;

  String _selectedWheelSize = '700c';
  int _selectedTireWidth = 28;
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
    });
  }

  void _calculateAndSaveCircumference() {
    // Find the wheel diameter
    final wheel = wheelSizes.firstWhere(
      (w) => w['name'] == _selectedWheelSize,
      orElse: () => {'diameterMm': 622},
    );

    final rimDiameterMm = wheel['diameterMm'] as int;
    final tireWidthMm = _selectedTireWidth;

    // Circumference = π × (rim_diameter + 2 × tire_width)
    // In meters: (rim_diameter_mm + 2 × tire_width_mm) / 1000 × π
    final diameterM = (rimDiameterMm + 2 * tireWidthMm) / 1000;
    final circumferenceM = diameterM * 3.14159265359;

    setState(() {
      _calculatedCircumference = circumferenceM;
    });

    // Save all settings
    _prefs.setString('wheel_size', _selectedWheelSize);
    _prefs.setInt('tire_width', _selectedTireWidth);
    _prefs.setString('pressure_unit', _selectedPressureUnit);
    _prefs.setString('speed_unit', _selectedSpeedUnit);
    _prefs.setDouble('wheel_circumference', circumferenceM);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Settings saved • Circumference: ${circumferenceM.toStringAsFixed(3)}m'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgLight,
        body: const Center(child: CircularProgressIndicator(color: accentGemini)),
      );
    }

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        title: const Text(
          'SETTINGS',
          style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        foregroundColor: const Color(0xFF222222),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Wheel Configuration Section
            _buildSectionHeader('WHEEL CONFIGURATION'),
            const SizedBox(height: 12),

            // Wheel Size
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WHEEL SIZE',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accentGemini.withOpacity(0.3)),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedWheelSize,
                        isExpanded: true,
                        underline: const SizedBox(),
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: accentGemini, fontSize: 14, fontWeight: FontWeight.w500),
                        items: wheelSizes.map((size) {
                          return DropdownMenuItem<String>(
                            value: size['name'] as String,
                            child: Text(size['name'] as String),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedWheelSize = value);
                            _calculateAndSaveCircumference();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Tire Width
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TIRE WIDTH (mm)',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accentGemini.withOpacity(0.3)),
                      ),
                      child: DropdownButton<int>(
                        value: _selectedTireWidth,
                        isExpanded: true,
                        underline: const SizedBox(),
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: accentGemini, fontSize: 14, fontWeight: FontWeight.w500),
                        items: tireWidths.map((width) {
                          return DropdownMenuItem<int>(
                            value: width,
                            child: Text('$width mm'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedTireWidth = value);
                            _calculateAndSaveCircumference();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Calculated Circumference Display
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CALCULATED WHEEL CIRCUMFERENCE',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: accentGemini.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accentGemini.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${_calculatedCircumference.toStringAsFixed(3)} meters',
                        style: const TextStyle(
                          color: accentGemini,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Used for speed calculations from wheel rotations',
                      style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Units Section
            _buildSectionHeader('UNIT PREFERENCES'),
            const SizedBox(height: 12),

            // Tire Pressure Unit
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TIRE PRESSURE UNIT',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: pressureUnits.map((unit) {
                        final isSelected = _selectedPressureUnit == unit;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedPressureUnit = unit);
                                _prefs.setString('pressure_unit', unit);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? accentGemini.withOpacity(0.15) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? accentGemini : cardBorder,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Text(
                                  unit,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSelected ? accentGemini : Color(0xFF888888),
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Speed Unit
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SPEED UNIT',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: speedUnits.map((unit) {
                        final isSelected = _selectedSpeedUnit == unit;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedSpeedUnit = unit);
                                _prefs.setString('speed_unit', unit);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? accentGemini.withOpacity(0.15) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? accentGemini : cardBorder,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Text(
                                  unit,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSelected ? accentGemini : Color(0xFF888888),
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Info Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardGrey,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ℹ Wheel Circumference Calculation',
                    style: TextStyle(color: accentGemini, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Circumference = π × (rim_diameter + 2 × tire_width)\n\n'
                    'This is used to calculate your speed from wheel rotations measured by the CSC (Cadence & Speed) sensor.',
                    style: TextStyle(color: Color(0xFF888888), fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: accentGemini,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }
}
