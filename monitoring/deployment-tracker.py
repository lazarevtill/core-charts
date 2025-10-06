#!/usr/bin/env python3
"""
Deployment Tracker for Grafana Annotations
Watches Kubernetes deployments and posts annotations to Grafana
"""

import os
import time
import requests
import urllib.parse
from datetime import datetime
from kubernetes import client, config, watch

# Configuration
GRAFANA_URL = os.getenv('GRAFANA_URL', 'http://grafana.monitoring.svc.cluster.local:3000')
GRAFANA_USER = os.getenv('GRAFANA_USER', 'admin')
GRAFANA_PASSWORD = os.getenv('GRAFANA_PASSWORD', 'admin123')
GITHUB_TOKEN = os.getenv('GITHUB_TOKEN', '')  # Optional for higher rate limits
GITHUB_REPO = 'uz0/core-pipeline'
NAMESPACES = ['core-pipeline-production', 'core-pipeline-test']

# Grafana dashboard UID where annotations should appear
DASHBOARD_UID = 'core-pipeline-red'

def get_latest_commit_info():
    """Fetch latest commit info from GitHub API"""
    url = f'https://api.github.com/repos/{GITHUB_REPO}/commits/main'
    headers = {}
    if GITHUB_TOKEN:
        headers['Authorization'] = f'token {GITHUB_TOKEN}'

    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        commit_data = response.json()

        return {
            'sha': commit_data['sha'][:7],
            'full_sha': commit_data['sha'],
            'message': commit_data['commit']['message'].split('\n')[0],
            'author': commit_data['commit']['author']['name'],
            'url': commit_data['html_url'],
            'date': commit_data['commit']['author']['date']
        }
    except Exception as e:
        print(f"Error fetching commit info: {e}")
        return None

def post_grafana_annotation(text, tags, timestamp=None, namespace=None, pod_name=None):
    """Post annotation to Grafana with optional log links"""
    if timestamp is None:
        timestamp = int(time.time() * 1000)

    # Build Loki query URL if namespace and pod provided
    if namespace and pod_name:
        # URL-encode the Loki query
        import urllib.parse
        loki_query = f'{{namespace="{namespace}",pod=~"{pod_name}.*"}}'
        loki_url = (
            f'https://grafana.theedgestory.org/explore?'
            f'orgId=1&'
            f'left={urllib.parse.quote(f\'["now-1h","now","loki",{{"expr":"{loki_query}"}}]\')}'
        )
        text_with_link = f'{text}<br/><a href="{loki_url}" target="_blank">📋 View Deployment Logs</a>'
    else:
        text_with_link = text

    annotation = {
        'dashboardUID': DASHBOARD_UID,
        'time': timestamp,
        'tags': tags,
        'text': text_with_link
    }

    url = f'{GRAFANA_URL}/api/annotations'

    try:
        response = requests.post(
            url,
            json=annotation,
            auth=(GRAFANA_USER, GRAFANA_PASSWORD),
            timeout=10
        )
        response.raise_for_status()
        print(f"✅ Posted annotation: {text}")
        return True
    except Exception as e:
        print(f"❌ Error posting annotation: {e}")
        return False

def watch_deployments():
    """Watch for new pod deployments"""
    # Load Kubernetes config
    try:
        config.load_incluster_config()
    except:
        config.load_kube_config()

    v1 = client.CoreV1Api()
    w = watch.Watch()

    print(f"👀 Watching deployments in namespaces: {NAMESPACES}")

    # Track seen pods to avoid duplicates
    seen_pods = set()

    for namespace in NAMESPACES:
        try:
            # Get existing pods first
            pods = v1.list_namespaced_pod(namespace, label_selector='app=kuberoapp')
            for pod in pods.items:
                seen_pods.add(pod.metadata.uid)
        except Exception as e:
            print(f"Error listing pods in {namespace}: {e}")

    # Watch for new pods
    while True:
        try:
            for namespace in NAMESPACES:
                for event in w.stream(
                    v1.list_namespaced_pod,
                    namespace=namespace,
                    label_selector='app=kuberoapp',
                    timeout_seconds=30
                ):
                    pod = event['object']
                    event_type = event['type']

                    # Only process ADDED events for new pods
                    if event_type == 'ADDED' and pod.metadata.uid not in seen_pods:
                        seen_pods.add(pod.metadata.uid)

                        # Wait a bit for pod to start
                        time.sleep(2)

                        # Get commit info
                        commit_info = get_latest_commit_info()

                        if commit_info:
                            env = 'production' if 'production' in namespace else 'development'

                            text = f"""
**Deployment: {env}**
Commit: [{commit_info['sha']}]({commit_info['url']})
Message: {commit_info['message']}
Author: {commit_info['author']}
Pod: {pod.metadata.name}
                            """.strip()

                            tags = ['deployment', env, commit_info['sha']]

                            timestamp = int(datetime.now().timestamp() * 1000)
                            post_grafana_annotation(
                                text,
                                tags,
                                timestamp,
                                namespace=namespace,
                                pod_name=pod.metadata.name
                            )

                        print(f"📦 New deployment detected: {pod.metadata.name} in {namespace}")

        except Exception as e:
            print(f"Error in watch loop: {e}")
            time.sleep(5)
            continue

if __name__ == '__main__':
    print("🚀 Starting Deployment Tracker...")
    watch_deployments()
