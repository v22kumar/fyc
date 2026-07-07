import subprocess
import json
import re

def run_cmd(cmd, cwd="/root/fyc"):
    return subprocess.check_output(cmd, shell=True, cwd=cwd, text=True, stderr=subprocess.DEVNULL)

branches = run_cmd("git for-each-ref --format='%(refname:short)' refs/heads/ refs/remotes/origin/").splitlines()
branches = [b for b in branches if b != 'origin/HEAD' and not b.endswith('/HEAD')]

main_branch = 'origin/main'

branch_data = []

for b in branches:
    b_type = "Local" if not b.startswith("origin/") else "Remote"
    name = b
    if b == "main" or b == "origin/main":
        continue

    try:
        # Commit info
        sha = run_cmd(f"git rev-parse {b}").strip()
        msg = run_cmd(f"git log -1 --format='%s' {b}").strip()
        author = run_cmd(f"git log -1 --format='%an' {b}").strip()
        date = run_cmd(f"git log -1 --format='%ci' {b}").strip()

        # Ahead/Behind
        ab = run_cmd(f"git rev-list --left-right --count {main_branch}...{b}").strip()
        behind, ahead = map(int, ab.split())

        # Merge status
        is_merged = (behind > 0 and ahead == 0)

        # Files changed (comparing merge base to branch)
        merge_base = run_cmd(f"git merge-base {main_branch} {b}").strip()
        files_changed_raw = run_cmd(f"git diff --name-only {merge_base}...{b}").strip().splitlines()
        
        # Check if fully merged by tree / cherry-pick
        # If ahead > 0, maybe it was cherry-picked or squash-merged?
        # We can check if diff between main and branch is empty for those files?
        # Or just use the Ahead/Behind as primary indicator.
        
        # TODOs count
        todos = 0
        try:
            todos = len(run_cmd(f"git grep -i 'TODO\\|FIXME\\|HACK' {b}").strip().splitlines())
        except:
            pass

        branch_data.append({
            "name": name,
            "type": b_type,
            "sha": sha,
            "message": msg,
            "author": author,
            "date": date,
            "ahead": ahead,
            "behind": behind,
            "is_merged": is_merged,
            "files": files_changed_raw[:20], # limit to 20
            "total_files": len(files_changed_raw),
            "todos": todos
        })
    except Exception as e:
        print(f"Error on {b}: {e}")

with open("branch_audit.json", "w") as f:
    json.dump(branch_data, f, indent=2)

print("Done!")
