import json

with open('test_data/coast_down_20260129_194342.jsonl', 'r') as f:
    for i, line in enumerate(f):
        if i < 30:  # First 30 lines
            data = json.loads(line)
            print(f"Line {i}: type={data.get('type')}, keys={list(data.keys())}")
        else:
            break
