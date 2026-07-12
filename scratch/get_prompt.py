import json

log_path = r"C:\Users\VarunKumar_Sv\.gemini\antigravity\brain\667d20c2-c7ca-449d-93eb-720dc1b6423e\.system_generated\logs\transcript.jsonl"

with open(log_path, 'r', encoding='utf-8') as f:
    for line in f:
        data = json.loads(line)
        if data.get("type") == "USER_INPUT":
            content = data.get("content", "")
            if "continue from sprint 2" in content:
                with open("scratch/goal_details.txt", "w", encoding="utf-8") as out:
                    out.write(content)
                print("Wrote goal details to scratch/goal_details.txt")
                break
