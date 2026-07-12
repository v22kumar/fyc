import json
import re

log_path = r"C:\Users\VarunKumar_Sv\.gemini\antigravity\brain\667d20c2-c7ca-449d-93eb-720dc1b6423e\.system_generated\logs\transcript.jsonl"

pattern = re.compile(r'sprint\s*\d', re.IGNORECASE)

with open(log_path, 'r', encoding='utf-8') as f:
    for idx, line in enumerate(f):
        data = json.loads(line)
        content = data.get("content", "")
        matches = pattern.findall(content)
        if matches:
            print(f"Index: {idx}, Step: {data.get('step_index')}, Source: {data.get('source')}, Matches: {matches}")
