import json
import requests
import time
from argparse import ArgumentParser
import os
import subprocess

# Parse arguments
parser = ArgumentParser(description="Send webhooks to Jenkins")
parser.add_argument('--max', type=int, default=-1, help="Maximum number of webhooks to send")
parser.add_argument('--pause', type=float, default=10, help="Number of seconds to wait between each webhook")
parser.add_argument('--message', type=str, default="[Test] Webhook", help="Commit message")
parser.add_argument('--repository_url', type=str, default="https://github.com/uiaict/2024-ikt218-osdev")

args = parser.parse_args()

# Maximum amount of webhooks to send
max_to_send = args.max

# Pause between each webhook
pause = args.pause

# Commit message
message = args.message

# Number of webhooks sent
sent = 0

# Repository URL
repository_url = args.repository_url

owner = repository_url.split('/')[3]
repo = repository_url.split('/')[4]

# Webhook endpoint URL
webhook_url = 'http://atos.ddns.net:30080/jenkins/generic-webhook-trigger/invoke?token=ikt218'


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
