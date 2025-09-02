#!/usr/bin/env fish

echo "Starting Homelab Agent Node..."

# Set environment variables for agent node
set -x HOMELAB_NODE_ID "agent-1"
set -x HOMELAB_NODE_NAME "Agent Node 1"
set -x HOMELAB_NODE_ROLE "agent"
set -x HOMELAB_PORT "4002"
set -x HOMELAB_DISCOVERY_PORT "4003"
set -x HOMELAB_BIND_ADDRESS "127.0.0.1"
set -x HOMELAB_CAPABILITIES "monitoring,compute,storage"
set -x HOMELAB_CLUSTERING "true"
set -x HOMELAB_AUTO_DISCOVERY "true"
set -x HOMELAB_WEB_INTERFACE "false"
set -x HOMELAB_API_ENDPOINTS "true"
set -x HOMELAB_HEALTH_CHECKS "true"
set -x HOMELAB_METRICS_COLLECTION "true"
set -x HOMELAB_DEBUG "true"
set -x HOMELAB_ENVIRONMENT "development"

echo ""
echo "Configuration:"
echo "  Node ID: $HOMELAB_NODE_ID"
echo "  Node Name: $HOMELAB_NODE_NAME"
echo "  Role: $HOMELAB_NODE_ROLE"
echo "  Port: $HOMELAB_PORT"
echo "  Discovery Port: $HOMELAB_DISCOVERY_PORT"
echo "  Bind Address: $HOMELAB_BIND_ADDRESS"
echo "  Clustering: $HOMELAB_CLUSTERING"
echo "  Capabilities: $HOMELAB_CAPABILITIES"
echo ""
echo "Starting agent node..."
echo ""

# Start the agent node
gleam run
