import json
import requests
import time
import os
import subprocess
from tqdm import tqdm

# Repository URL
repository_url = "https://github.com/uiaict/2024-ikt218-osdev"

owner = repository_url.split('/')[3]
repo = repository_url.split('/')[4]

forks = []
page = 1

while True:
    api_url = f"https://api.github.com/repos/{owner}/{repo}/forks?page={page}&per_page=100"
    
    response = requests.get(api_url)
    
    data = response.json()


    if not data:
        break

    forks.extend(fork['html_url'] for fork in data)

    page += 1


print("\nFetched", len(forks), "forks")

for i, url in enumerate(tqdm(forks, desc="Cloning", unit="repo", bar_format="{l_bar}{bar}| {n_fmt}/{total_fmt} [{elapsed}]")):
    folder_name = f"fork{i + 1}"
    clone_command = f"git clone {url} students/{folder_name} > /dev/null 2>&1"
    subprocess.run(clone_command, shell=True)
subprocess.run(clone_command, shell=True)
