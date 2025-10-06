#!/bin/bash
set -e

echo "🔧 Install kubectl-mcp-server on K3s cluster"
echo "=============================================="
echo ""

# Check if running on server or locally
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  echo "✅ Running on K3s server"
elif [ -f ~/.kube/config ]; then
  export KUBECONFIG=~/.kube/config
  echo "✅ Using local kubeconfig"
else
  echo "❌ No kubeconfig found"
  exit 1
fi

echo "Using KUBECONFIG: $KUBECONFIG"
echo ""

echo "1️⃣ Installing Python dependencies..."
python3 -m pip install --upgrade pip
pip3 install mcp>=1.5.0

echo ""
echo "2️⃣ Cloning kubectl-mcp-server..."
cd /tmp
rm -rf kubectl-mcp-server
git clone https://github.com/rohitg00/kubectl-mcp-server.git
cd kubectl-mcp-server

echo ""
echo "3️⃣ Installing kubectl-mcp-tool..."
pip3 install -e .

echo ""
echo "4️⃣ Creating directories for AI assistants..."
mkdir -p ~/.cursor
mkdir -p ~/.cursor/logs
mkdir -p ~/.config/claude
mkdir -p ~/.config/windsurf

echo ""
echo "5️⃣ Getting Python and kubectl paths..."
PYTHON_PATH=$(which python3)
KUBECTL_PATH=$(which kubectl)
echo "   Python: $PYTHON_PATH"
echo "   kubectl: $KUBECTL_PATH"

echo ""
echo "6️⃣ Creating MCP config for Claude Desktop..."
cat > ~/.config/claude/mcp.json << EOF
{
  "mcpServers": {
    "kubernetes": {
      "command": "$PYTHON_PATH",
      "args": ["-m", "kubectl_mcp_tool.cli.cli", "serve"],
      "env": {
        "KUBECONFIG": "$KUBECONFIG"
      }
    }
  }
}
EOF
echo "   ✅ Config written to ~/.config/claude/mcp.json"

echo ""
echo "7️⃣ Testing kubectl-mcp installation..."
kubectl-mcp --help | head -10

echo ""
echo "8️⃣ Testing kubectl access..."
kubectl version --client --short 2>/dev/null || kubectl version --client

echo ""
echo "9️⃣ Testing cluster connectivity..."
kubectl get nodes

echo ""
echo "✅ INSTALLATION COMPLETE!"
echo ""
echo "📋 kubectl-mcp-server is now installed and configured to use:"
echo "   KUBECONFIG: $KUBECONFIG"
echo ""
echo "🔧 To test the MCP server:"
echo "   kubectl-mcp serve"
echo ""
echo "🤖 If you use Claude Desktop app:"
echo "   1. Restart Claude Desktop"
echo "   2. The 'kubernetes' MCP server will be available"
echo "   3. You can ask Claude to interact with your K3s cluster"
echo ""
echo "⚠️  Note: This is for Claude Desktop app, not Claude Code CLI"
