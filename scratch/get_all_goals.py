import json

log_path = r"C:\Users\VarunKumar_Sv\.gemini\antigravity\brain\667d20c2-c7ca-449d-93eb-720dc1b6423e\.system_generated\logs\transcript.jsonl"

with open(log_path, 'r', encoding='utf-8') as f:
    for idx, line in enumerate(f):
        data = json.loads(line)
        content = data.get("content", "")
        if "/goal" in content:
            print(f"Index: {idx}, Step: {data.get('step_index')}, Length: {len(content)}, Source: {data.get('source')}")
            if len(content) > 1000 and "continue from sprint 2" in content:
                # write the untruncated one if found
                with open(f"scratch/untruncated_goal_{idx}.txt", "w", encoding="utf-8") as out:
                    out.write(content)
                print(f"Wrote to scratch/untruncated_goal_{idx}.txt")
