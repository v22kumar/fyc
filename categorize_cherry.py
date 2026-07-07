import json
import subprocess

with open("branch_audit.json") as f:
    branches = json.load(f)

for b in branches:
    if b['name'] == 'origin' or b['name'] == 'main': continue
    
    # Run git cherry to see if the commits on this branch are already in main
    cherry_output = subprocess.check_output(f"git cherry origin/main {b['name']}", shell=True, text=True).strip().splitlines()
    
    unmerged_commits = [line for line in cherry_output if line.startswith('+')]
    
    if len(unmerged_commits) == 0:
        b['real_status'] = 'Merged'
    elif b['ahead'] == 0:
        b['real_status'] = 'Merged'
    else:
        b['real_status'] = 'Unmerged'

for b in branches:
    if 'real_status' in b:
        print(f"{b['name']:<50} {b['real_status']}")

with open("branch_audit_final.json", "w") as f:
    json.dump(branches, f, indent=2)

