import json

log_path = r"C:\Users\VarunKumar_Sv\.gemini\antigravity\brain\667d20c2-c7ca-449d-93eb-720dc1b6423e\.system_generated\logs\transcript.jsonl"

with open(log_path, 'r', encoding='utf-8') as f:
    for idx, line in enumerate(f):
        data = json.loads(line)
        content = data.get("content", "")
        if "Sprint 3" in content or "Sprint 4" in content:
            print(f"Index: {idx}, Step: {data.get('step_index')}, Length: {len(content)}")
            if "<truncated" not in content or "continue from sprint 2" not in content:
                print("Content preview:")
                print(content[:500])
                print("-" * 50)
