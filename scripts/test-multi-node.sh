#!/usr/bin/env bash

# Multi-Node Homelab System Test Script
# This script helps test distributed node discovery and clustering functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="homelab-test-cluster"
BASE_PORT=4000
LOG_DIR="./logs"
PID_DIR="./pids"

# Node configurations - using arrays instead of associative arrays for compatibility
NODES_NAMES=("coordinator" "agent1" "agent2" "gateway")
NODES_CONFIG=(
    "Coordinator 4000"
    "Agent 4001 Monitoring"
    "Agent 4002 Storage"
    "Gateway 4003"
)

# Helper functions
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Setup directories
setup_dirs() {
    log "Setting up test directories..."
    mkdir -p "$LOG_DIR" "$PID_DIR"

    # Clean up any existing log files
    rm -f "$LOG_DIR"/*.log "$PID_DIR"/*.pid
}

# Start a single node
start_node() {
    local node_name="$1"
    local node_config="$2"

    # Parse node config
    IFS=' ' read -ra CONFIG <<< "$node_config"
    local role="${CONFIG[0]}"
    local port="${CONFIG[1]}"
    local agent_type="${CONFIG[2]:-Generic}"

    log "Starting node: $node_name ($role on port $port)"

    # Start the node in background with environment variables
    cd "$(dirname "$0")/.."

    # Use a wrapper script approach for better process management
    (
        export NODE_ID="$node_name"
        export NODE_NAME="homelab-$node_name"
        export NODE_ROLE="$role"
        export AGENT_TYPE="$agent_type"
        export CLUSTER_NAME="$CLUSTER_NAME"
        export BIND_PORT="$port"
        export BIND_ADDRESS="127.0.0.1"
        export ENVIRONMENT="testing"
        export DEBUG_MODE="true"
        export CLUSTERING_ENABLED="true"
        export WEB_INTERFACE_ENABLED="true"
        export DISCOVERY_METHOD="multicast"
        export DISCOVERY_PORT="$((port + 1000))"

        exec gleam run
    ) > "$LOG_DIR/$node_name.log" 2>&1 &

    local pid=$!

    # Save PID for cleanup
    echo $pid > "$PID_DIR/$node_name.pid"

    success "Node $node_name started (PID: $pid)"

    # Wait a moment for the node to initialize
    sleep 3
}

# Stop a single node
stop_node() {
    local node_name="$1"
    local pid_file="$PID_DIR/$node_name.pid"

    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log "Stopping node: $node_name (PID: $pid)"
            kill -TERM "$pid" 2>/dev/null || true

            # Wait for graceful shutdown
            local count=0
            while kill -0 "$pid" 2>/dev/null && [[ $count -lt 10 ]]; do
                sleep 1
                ((count++))
            done

            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                warn "Force killing node $node_name"
                kill -KILL "$pid" 2>/dev/null || true
            fi

            success "Node $node_name stopped"
        fi
        rm -f "$pid_file"
    else
        warn "No PID file found for node: $node_name"
    fi
}

# Start all nodes
start_cluster() {
    log "Starting multi-node cluster test..."
    setup_dirs

    # Start coordinator first
    start_node "coordinator" "${NODES_CONFIG[0]}"

    # Wait for coordinator to be ready
    sleep 5

    # Start other nodes
    for i in "${!NODES_NAMES[@]}"; do
        local node_name="${NODES_NAMES[$i]}"
        if [[ "$node_name" != "coordinator" ]]; then
            start_node "$node_name" "${NODES_CONFIG[$i]}"
            sleep 3
        fi
    done

    success "All nodes started. Cluster should be forming..."

    # Show status
    show_status
}

# Stop all nodes
stop_cluster() {
    log "Stopping all cluster nodes..."

    for node_name in "${NODES_NAMES[@]}"; do
        stop_node "$node_name"
    done

    success "All nodes stopped"
    cleanup
}

# Show cluster status
show_status() {
    log "Cluster Status:"
    echo

    for i in "${!NODES_NAMES[@]}"; do
        local node_name="${NODES_NAMES[$i]}"
        local pid_file="$PID_DIR/$node_name.pid"
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                IFS=' ' read -ra CONFIG <<< "${NODES_CONFIG[$i]}"
                local port="${CONFIG[1]}"
                success "$node_name: RUNNING (PID: $pid, Port: $port)"
            else
                error "$node_name: STOPPED (stale PID file)"
                rm -f "$pid_file"
            fi
        else
            error "$node_name: NOT STARTED"
        fi
    done

    echo
    log "Log files available in: $LOG_DIR/"
    log "PID files available in: $PID_DIR/"
}

# Follow logs from all nodes
follow_logs() {
    local node_filter="${1:-}"

    if [[ -n "$node_filter" ]]; then
        if [[ -f "$LOG_DIR/$node_filter.log" ]]; then
            log "Following logs for: $node_filter"
            tail -f "$LOG_DIR/$node_filter.log"
        else
            error "Log file not found for: $node_filter"
            exit 1
        fi
    else
        log "Following logs for all nodes..."
        if command -v multitail >/dev/null 2>&1; then
            multitail "$LOG_DIR"/*.log
        else
            # Fallback to tail with basic multiplexing
            tail -f "$LOG_DIR"/*.log 2>/dev/null | while IFS= read -r line; do
                echo "[$(date '+%H:%M:%S')] $line"
            done
        fi
    fi
}

# Test node communication
test_communication() {
    log "Testing node communication..."

    # Check if nodes are responding on their ports
    for i in "${!NODES_NAMES[@]}"; do
        local node_name="${NODES_NAMES[$i]}"
        IFS=' ' read -ra CONFIG <<< "${NODES_CONFIG[$i]}"
        local port="${CONFIG[1]}"

        if command -v nc >/dev/null 2>&1; then
            if nc -z 127.0.0.1 "$port" 2>/dev/null; then
                success "$node_name: Port $port is open"
            else
                warn "$node_name: Port $port is not responding"
            fi
        else
            warn "netcat (nc) not available - skipping port checks"
            break
        fi
    done
}

# Cleanup function
cleanup() {
    log "Cleaning up test files..."
    rm -rf "$LOG_DIR" "$PID_DIR"
}

# Show help
show_help() {
    cat << EOF
Multi-Node Homelab System Test Script

Usage: $0 <command> [options]

Commands:
    start           Start the multi-node cluster
    stop            Stop all cluster nodes
    restart         Stop and start the cluster
    status          Show current cluster status
    logs [node]     Follow logs (all nodes or specific node)
    test            Test node communication
    cleanup         Clean up test files
    help            Show this help message

Node Configuration:
    coordinator     - Cluster coordinator (port 4000)
    agent1          - Monitoring agent (port 4001)
    agent2          - Storage agent (port 4002)
    gateway         - Gateway node (port 4003)

Examples:
    $0 start                    # Start all nodes
    $0 logs coordinator         # Follow coordinator logs
    $0 logs                     # Follow all logs
    $0 status                   # Check cluster status
    $0 stop                     # Stop all nodes

Logs Directory: $LOG_DIR/
PID Directory:  $PID_DIR/
EOF
}

# Signal handlers
trap 'log "Interrupted. Stopping cluster..."; stop_cluster; exit 130' INT TERM

# Main command handling
case "${1:-help}" in
    "start")
        start_cluster
        ;;
    "stop")
        stop_cluster
        ;;
    "restart")
        stop_cluster
        sleep 2
        start_cluster
        ;;
    "status")
        show_status
        ;;
    "logs")
        follow_logs "$2"
        ;;
    "test")
        test_communication
        ;;
    "cleanup")
        stop_cluster
        cleanup
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        error "Unknown command: $1"
        echo
        show_help
        exit 1
        ;;
esac
