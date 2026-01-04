import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PressureRun {
  final int id;
  final double front;
  final double rear;
  final String unit;

  PressureRun(this.id, this.front, this.rear, this.unit);
}

class PressureInputPage extends StatefulWidget {
  const PressureInputPage({super.key});

  @override
  State<PressureInputPage> createState() => _PressureInputPageState();
}

class _PressureInputPageState extends State<PressureInputPage> {
  final TextEditingController _frontController = TextEditingController();
  final TextEditingController _rearController = TextEditingController();
  final List<PressureRun> _completedRuns = [];
  int _selectedUnitIndex = 0;

  // Pastel Color Palette
  static const Color pastelBlue = Color(0xFFAEC6CF);
  static const Color pastelGreen = Color(0xFF77DD77);
  static const Color pastelBackground = Color(0xFFFDFDFD);
  static const Color pastelInputGrey = Color(0xFFF4F4F4);

  @override
  void initState() {
    super.initState();
    _rearController.addListener(_updateFrontPressure);
  }

  void _updateFrontPressure() {
    final double? rearValue = double.tryParse(_rearController.text);
    if (rearValue != null) {
      // 51/49 Weight Distribution Ratio
      double calculatedFront = (rearValue / 51) * 49;
      _frontController.text = calculatedFront.toStringAsFixed(_selectedUnitIndex == 0 ? 1 : 2);
    } else {
      _frontController.clear();
    }
  }

  void _startRun() {
    final double? front = double.tryParse(_frontController.text);
    final double? rear = double.tryParse(_rearController.text);

    if (front != null && rear != null) {
      setState(() {
        _completedRuns.add(PressureRun(
          _completedRuns.length + 1, 
          front, 
          rear,
          _selectedUnitIndex == 0 ? "PSI" : "Bar"
        ));
      });
      _rearController.clear();
      _frontController.clear();
      FocusScope.of(context).unfocus(); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: pastelBackground,
      navigationBar: CupertinoNavigationBar(
        // FIXED: Explicit iOS Back Arrow
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back, color: CupertinoColors.activeBlue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        middle: const Text("Tyre Protocol", style: TextStyle(fontWeight: FontWeight.w400)),
        backgroundColor: pastelBackground.withOpacity(0.9),
        border: const Border(bottom: BorderSide(color: CupertinoColors.separator, width: 0.5)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              // UNIT SELECTOR
              SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _selectedUnitIndex,
                  thumbColor: Colors.white,
                  backgroundColor: CupertinoColors.systemGrey6,
                  children: const {
                    0: Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text("PSI")),
                    1: Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text("BAR")),
                  },
                  onValueChanged: (v) => setState(() {
                    _selectedUnitIndex = v!;
                    _rearController.clear();
                  }),
                ),
              ),
              const SizedBox(height: 30),

              // INPUT SECTION
              Row(
                children: [
                  _buildPastelInput(_rearController, "REAR [INPUT]", true),
                  const SizedBox(width: 15),
                  _buildPastelInput(_frontController, "FRONT [AUTO]", false),
                ],
              ),
              const SizedBox(height: 25),

              // ACTION BUTTON (Pastel Blue)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: CupertinoButton(
                  color: pastelBlue,
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _startRun,
                  child: const Text("Start Run", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: 35),

              // DATA LOG
              const Text(" COMPLETE RUNS LOG", 
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CupertinoColors.systemGrey)),
              const SizedBox(height: 10),
              
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: CupertinoColors.systemGrey5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Material(
                      color: Colors.transparent,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowHeight: 40,
                          headingRowColor: MaterialStateProperty.all(pastelInputGrey),
                          columns: const [
                            DataColumn(label: Text('ID', style: TextStyle(fontSize: 11))),
                            DataColumn(label: Text('FRONT', style: TextStyle(fontSize: 11))),
                            DataColumn(label: Text('REAR', style: TextStyle(fontSize: 11))),
                            DataColumn(label: Text('UNIT', style: TextStyle(fontSize: 11))),
                          ],
                          rows: _completedRuns.map((run) => DataRow(cells: [
                            DataCell(Text('#${run.id}')),
                            DataCell(Text(run.front.toString(), style: const TextStyle(color: pastelBlue, fontWeight: FontWeight.bold))),
                            DataCell(Text(run.rear.toString())),
                            DataCell(Text(run.unit, style: const TextStyle(fontSize: 10))),
                          ])).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // FINISH ACTION (Pastel Green)
              if (_completedRuns.length >= 3)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: CupertinoButton(
                      color: pastelGreen,
                      borderRadius: BorderRadius.circular(15),
                      onPressed: () {},
                      child: const Text("Finish and Calculate", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPastelInput(TextEditingController controller, String label, bool enabled) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(" $label", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CupertinoColors.systemGrey2)),
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: controller,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: enabled ? CupertinoColors.label : CupertinoColors.systemGrey),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: enabled ? Colors.white : pastelInputGrey,
              border: Border.all(color: CupertinoColors.systemGrey5),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }
}