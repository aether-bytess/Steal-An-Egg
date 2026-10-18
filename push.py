import os
import sys
from dulwich import porcelain

root_dir = os.path.dirname(os.path.abspath(__file__))

env_path = os.path.join(root_dir, '.env')
token = None
user = 'gamesensecoder'
repo_name = 'Steal-An-Egg'

if os.path.exists(env_path):
    with open(env_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('GITHUB_TOKEN='):
                token = line.split('=', 1)[1].strip()
            elif line.startswith('GITHUB_USER='):
                user = line.split('=', 1)[1].strip()
            elif line.startswith('GITHUB_REPO='):
                repo_name = line.split('=', 1)[1].strip()

if not token:
    print("Error: GITHUB_TOKEN not found in .env")
    sys.exit(1)

commit_msg = sys.argv[1].encode('utf-8') if len(sys.argv) > 1 else b"Update Steal-An-Egg"

print(f"Adding all changes in {root_dir}...")
porcelain.add(root_dir)

try:
    commit_id = porcelain.commit(
        root_dir,
        message=commit_msg,
        author=f"{user} <baranovilya10@gmail.com>".encode('utf-8'),
        committer=f"{user} <baranovilya10@gmail.com>".encode('utf-8')
    )
    print(f"Created commit: {commit_id.decode() if isinstance(commit_id, bytes) else commit_id}")
except Exception as e:
    print(f"Commit status: {e}")

remote_url = f"https://{user}:{token}@github.com/{user}/{repo_name}.git"
print(f"Pushing to https://github.com/{user}/{repo_name}...")
porcelain.push(root_dir, remote_url, refspecs=[b'refs/heads/main:refs/heads/main'])
print("Successfully pushed to GitHub!")
