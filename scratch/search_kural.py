import os

base_dir = r"c:\WorkStation\FYC_Connect"

terms = ["kural", "thirukkural", "dailynewscard", "dailythirukkuralcard"]

for root, dirs, files in os.walk(base_dir):
    # Skip .git and .venv
    if ".git" in root or ".venv" in root or "node_modules" in root:
        continue
    for f in files:
        if f.endswith((".dart", ".astro", ".js", ".ts", ".tsx", ".md")):
            path = os.path.join(root, f)
            try:
                with open(path, "r", encoding="utf-8", errors="ignore") as file:
                    content = file.read()
                for term in terms:
                    if term in content.lower():
                        # Find matching lines
                        lines = content.splitlines()
                        for idx, line in enumerate(lines):
                            if term in line.lower():
                                print(f"{f}:{idx+1}: {line.strip()}")
                        print("-" * 50)
                        break
            except Exception:
                pass
