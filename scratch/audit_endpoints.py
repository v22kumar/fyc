import os
import re

router_dir = r"c:\WorkStation\FYC_Connect\backend\app\routers"

for f in os.listdir(router_dir):
    if f.endswith(".py"):
        path = os.path.join(router_dir, f)
        with open(path, "r", encoding="utf-8") as file:
            content = file.read()
        
        # Look for def get_... or similar that has an id
        # Or look for query(...) calls
        queries = re.findall(r'db\.query\([^)]+\)\.filter\([^)]+\)', content)
        if queries:
            print(f"File: {f}")
            for q in queries:
                print(f"  Query: {q}")
            print("-" * 40)
