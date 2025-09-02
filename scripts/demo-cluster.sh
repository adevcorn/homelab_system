#!/bin/bash

# Demo Script for Multi-Node Homelab System Testing
# Shows complete workflow for testing distributed node discovery

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Helper functions
log() {
    echo -e "${BLUE}[DEMO]${NC} $1"
}

success() {
    echo -e "${GREEN}✅${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

error() {
    echo -e "${RED}❌${NC} $1"
}

title() {
    echo
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE} $1${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
    echo
}

pause() {
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
}

# Check prerequisites
check_prerequisites() {
    title "CHECKING PREREQUISITES"

    # Check if we're in the right directory
    if [[ ! -f "gleam.toml" ]]; then
        error "Please run this script from the homelab_system root directory"
        exit 1
    fi

    # Check if scripts exist
    if [[ ! -f "scripts/test-multi-node.sh" ]]; then
        error "Multi-node test script not found"
        exit 1
    fi

    if [[ ! -f "scripts/monitor-cluster.sh" ]]; then
        error "Cluster monitor script not found"
        exit 1
    fi

    # Check if system builds
    log "Checking if system compiles..."
    if gleam check >/dev/null 2>&1; then
        success "System compiles successfully"
    else
        error "System fails to compile - please fix build issues first"
        exit 1
    fi

    success "All prerequisites met!"
}

# Demo introduction
show_introduction() {
    title "HOMELAB MULTI-NODE CLUSTER DEMO"

    cat << EOF
This demo will show you how to:
1. Start a multi-node cluster (coordinator + agents + gateway)
2. Monitor cluster formation and node discovery
3. Test inter-node communication
4. Analyze cluster health and logs
5. Gracefully shutdown the cluster

The demo cluster consists of:
• coordinator (port 4000) - Cluster coordinator node
• agent1 (port 4001)     - Monitoring agent
• agent2 (port 4002)     - Storage agent
• gateway (port 4003)    - Gateway node

Each node will attempt to discover and communicate with others.
EOF

    pause
}

# Start the cluster
start_demo_cluster() {
    title "STEP 1: STARTING MULTI-NODE CLUSTER"

    log "Starting cluster with 4 nodes..."
    log "This will take about 10-15 seconds..."

    bash ./scripts/test-multi-node.sh start

    success "Cluster startup initiated!"

    log "Waiting for nodes to initialize..."
    sleep 8

    log "Checking cluster status..."
    bash ./scripts/test-multi-node.sh status

    pause
}

# Monitor cluster formation
monitor_cluster_formation() {
    title "STEP 2: MONITORING CLUSTER FORMATION"

    log "Running health check to verify node status..."
    ./scripts/monitor-cluster.sh health

    echo
    log "Testing network connectivity between nodes..."
    ./scripts/monitor-cluster.sh connectivity

    echo
    log "Let's look at what each node is doing..."
    echo -e "${YELLOW}Showing recent activity from each node:${NC}"

    # Show recent logs from each node
    for log_file in logs/*.log; do
        if [[ -f "$log_file" ]]; then
            local node_name=$(basename "$log_file" .log)
            echo
            echo -e "${BOLD}=== $node_name ====${NC}"
            tail -5 "$log_file" 2>/dev/null | head -3
        fi
    done

    pause
}

# Test cluster communication
test_cluster_communication() {
    title "STEP 3: TESTING CLUSTER COMMUNICATION"

    log "Analyzing logs for clustering and discovery messages..."
    ./scripts/monitor-cluster.sh analyze

    echo
    log "This shows us:"
    echo "  • Which nodes started successfully"
    echo "  • Any clustering or discovery issues"
    echo "  • Network and resource problems"

    pause
}

# Show real-time monitoring
show_realtime_monitoring() {
    title "STEP 4: REAL-TIME CLUSTER MONITORING"

    log "Now let's watch real-time cluster activity..."
    warn "This will show live logs from all nodes"
    warn "Press Ctrl+C to stop watching after 10-20 seconds"

    echo
    pause

    # Run real-time monitoring for a limited time
    timeout 15s ./scripts/monitor-cluster.sh watch || true

    echo
    success "Real-time monitoring demo completed"
}

# Generate cluster report
generate_demo_report() {
    title "STEP 5: GENERATING CLUSTER REPORT"

    log "Generating comprehensive cluster report..."
    ./scripts/monitor-cluster.sh report

    echo
    log "The report includes:"
    echo "  • Complete node status and configuration"
    echo "  • Network connectivity analysis"
    echo "  • Error summary and troubleshooting info"
    echo "  • Recent activity from all nodes"

    pause
}

# Test node failure scenario
test_failure_scenario() {
    title "STEP 6: TESTING NODE FAILURE SCENARIO"

    log "Let's simulate a node failure..."

    # Stop one agent
    log "Stopping agent1 node..."
    if [[ -f "pids/agent1.pid" ]]; then
        local pid=$(cat "pids/agent1.pid")
        kill -TERM "$pid" 2>/dev/null || true
        sleep 3
        rm -f "pids/agent1.pid"
        success "Agent1 stopped"
    fi

    log "Checking cluster status after node failure..."
    ./scripts/test-multi-node.sh status

    echo
    log "Running health check to see impact..."
    ./scripts/monitor-cluster.sh health

    echo
    log "In a real cluster, remaining nodes should:"
    echo "  • Detect the failed node"
    echo "  • Redistribute workloads"
    echo "  • Continue operating with degraded capacity"

    pause
}

# Cleanup and shutdown
cleanup_demo() {
    title "STEP 7: CLUSTER SHUTDOWN"

    log "Gracefully shutting down the cluster..."
    ./scripts/test-multi-node.sh stop

    success "All nodes stopped"

    echo
    log "Cleaning up demo files..."
    ./scripts/test-multi-node.sh cleanup

    success "Demo cleanup completed!"
}

# Show summary and next steps
show_summary() {
    title "DEMO COMPLETE - SUMMARY"

    cat << EOF
🎉 You've successfully completed the multi-node cluster demo!

What we demonstrated:
✅ Multi-node cluster startup and initialization
✅ Node discovery and clustering functionality
✅ Network connectivity and health monitoring
✅ Real-time log monitoring and analysis
✅ Comprehensive cluster reporting
✅ Failure scenario testing
✅ Graceful cluster shutdown

Next Steps:
1. Customize node configurations in scripts/test-multi-node.sh
2. Modify environment variables for different scenarios
3. Test with different discovery methods (DNS, static nodes)
4. Add your own monitoring and alerting logic
5. Scale up to more nodes by adding them to the NODES array

Useful Commands:
• ./scripts/test-multi-node.sh start     - Start cluster
• ./scripts/test-multi-node.sh status    - Check status
• ./scripts/monitor-cluster.sh health    - Health check
• ./scripts/monitor-cluster.sh monitor   - Continuous monitoring
• ./scripts/test-multi-node.sh logs      - Follow all logs
• ./scripts/test-multi-node.sh stop      - Stop cluster

Happy clustering! 🚀
EOF
}

# Main demo flow
run_demo() {
    check_prerequisites
    show_introduction
    start_demo_cluster
    monitor_cluster_formation
    test_cluster_communication
    show_realtime_monitoring
    generate_demo_report
    test_failure_scenario
    cleanup_demo
    show_summary
}

# Signal handlers
trap 'echo; warn "Demo interrupted. Cleaning up..."; ./scripts/test-multi-node.sh stop >/dev/null 2>&1 || true; exit 130' INT TERM

# Run the demo
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat << EOF
Homelab Multi-Node Cluster Demo

Usage: $0

This interactive demo will guide you through:
- Starting a multi-node cluster
- Monitoring node discovery and communication
- Testing cluster health and failure scenarios
- Generating comprehensive reports

Prerequisites:
- Run from homelab_system root directory
- System must compile successfully (gleam check)
- Multi-node test scripts must be present

The demo is fully interactive and will pause between steps.
Press Ctrl+C at any time to stop and cleanup.
EOF
else
    run_demo
fi
