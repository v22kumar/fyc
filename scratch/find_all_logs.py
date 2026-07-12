import os

base_dir = r"C:\Users\VarunKumar_Sv\.gemini\antigravity"
for root, dirs, files in os.walk(base_dir):
    for f in files:
        if f.endswith(".jsonl") or f.endswith(".txt") or f.endswith(".md"):
            path = os.path.join(root, f)
            print(f"{f}: {os.path.getsize(path)} bytes -> {path}")
