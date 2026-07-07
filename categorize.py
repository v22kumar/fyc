import json

with open("main_commits.txt") as f:
    main_log = f.read().lower()

with open("branch_audit.json") as f:
    branches = json.load(f)

for b in branches:
    # check if the commit message (without feat() prefixes) is in main log
    # or just check if the branch name is in main log, or simple string match of the commit message
    msg = b['message'].split('(#')[0].strip().lower()
    
    # some messages might not have (#...)
    if msg in main_log:
        b['real_status'] = 'Squash Merged'
    elif b['is_merged']:
        b['real_status'] = 'Fast-forward Merged'
    else:
        b['real_status'] = 'Unmerged'

for b in branches:
    print(f"{b['name']:<50} {b['real_status']}")
