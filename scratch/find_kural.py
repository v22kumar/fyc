import os

base_dir = r"c:\WorkStation\FYC_Connect"

for root, dirs, files in os.walk(base_dir):
    if ".git" in root or ".venv" in root or "node_modules" in root:
        continue
    for f in files:
        if f.endswith((".dart", ".astro", ".js", ".ts", ".tsx", ".md", ".json")):
            path = os.path.join(root, f)
            try:
                with open(path, "r", encoding="utf-8", errors="ignore") as file:
                    content = file.read()
                if "kural" in content.lower() or "news" in content.lower():
                    # print matching file
                    print(f"Match found in: {path}")
            except Exception:
                pass
