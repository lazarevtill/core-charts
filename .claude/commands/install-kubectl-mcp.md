---
description: Install kubectl-mcp-server
---

Install the kubectl-mcp-server package from GitHub:

Prerequisites:
- Python 3.9 or higher
- kubectl CLI with cluster access

Installation options:
1. From PyPI (recommended): `pip install kubectl-mcp-tool`
2. From GitHub: `pip install git+https://github.com/rohitg00/kubectl-mcp-server.git`
3. Using pipx (isolated): `pipx install kubectl-mcp-tool`

Verify installation:
```bash
kubectl-mcp --version
kubectl-mcp --help
kubectl-mcp get pods
```

Configuration for Claude Desktop:
Add to `~/.cursor/mcp.json` or Claude Desktop config:
```json
{
  "mcpServers": {
    "kubectl-mcp": {
      "command": "kubectl-mcp",
      "args": [],
      "env": {
        "KUBECONFIG": "~/.kube/config"
      }
    }
  }
}
```
