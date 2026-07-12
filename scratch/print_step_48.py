import json

log_path = r"C:\Users\VarunKumar_Sv\.gemini\antigravity\brain\667d20c2-c7ca-449d-93eb-720dc1b6423e\.system_generated\logs\transcript.jsonl"

with open(log_path, 'r', encoding='utf-8') as f:
    for idx, line in enumerate(f):
        if idx == 47:
            data = json.loads(line)
            print("STEP 48 CONTENT:")
            print(data.get("content"))
            break
