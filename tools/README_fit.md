FIT file inspection and conversion

This workspace includes two helper scripts to inspect and convert FIT files:

- `inspect_fit.py` — quick summary/preview of messages (examples).
- `fit_to_csv.py` — exports one CSV per FIT message type.

Requirements

- Python 3.x
- fitparse library

Install:

```bash
python -m pip install --user fitparse
```

Run the inspector:

```bash
python tools/inspect_fit.py test_data/coast_down_20260119_173429.fit
```

Convert FIT → CSV (creates `out/` by default):

```bash
python tools/fit_to_csv.py test_data/coast_down_20260119_173429.fit --out-dir tools/out
```

Garmin FitCSVTool alternative

If you prefer Garmin's official CSV layout, use the FIT SDK's `FitCSVTool.jar`:

1. Download the FIT SDK from Garmin: https://developer.garmin.com/fit/
2. Run:

```bash
java -jar FitCSVTool.jar -b input.fit output.csv
```

This produces CSV files matching Garmin's expected schema.

Notes

- If your environment cannot run `python`, use the Java tool above.
- The provided `fit_to_csv.py` aims for readability and debugging, not perfect parity with Garmin's schema.
