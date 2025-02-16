import json
import requests
import time
import os
import subprocess

# Repository URL
repository_url = "https://github.com/uiaict/2025-ikt218-osdev"

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


print("\nFound", len(forks), "forks")

for i, url in enumerate(forks):
    folder_name = f"fork{i + 1}"
    clone_command = f"git clone {url} students/{folder_name} > /dev/null 2>&1"
    subprocess.run(clone_command, shell=True)

    percentage = (i + 1) / len(forks) * 100
    bar_length = 50 # Length of bar
    filled_length = int(bar_length * percentage // 100)
    bar = '#' * filled_length + '-' * (bar_length - filled_length) 

    print(f"Cloning: [{bar}] {percentage:.1f}% complete", end="\r")

print("\nCloning complete.")
