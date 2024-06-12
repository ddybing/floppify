import json
import requests
import time
import os
import subprocess

# Repository URL
repository_url = "https://github.com/uiaict/2024-ikt218-osdev"

owner = repository_url.split('/')[3]
repo = repository_url.split('/')[4]


print("Fetching forks list for repo: ", repository_url )
forks = []
page = 1

while True:
    print('.', end='', flush=True)
    api_url = f"https://api.github.com/repos/{owner}/{repo}/forks?page={page}&per_page=100"
    
    response = requests.get(api_url)
    
    data = response.json()


    if not data:
        break

    forks.extend(fork['html_url'] for fork in data)

    page += 1




print("\nFetched ", len(forks), " forks")



print("\nCloning forks")


for url in forks:
    folder_name = f"fork{forks.index(url) + 1}"
    clone_command = f"git clone {url} students/{folder_name}"
    subprocess.run(clone_command, shell=True)
