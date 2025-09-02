#!/bin/bash

# Cluster Monitoring and Testing Utilities
# Monitors cluster health, node discovery, and communication

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
LOG_DIR="./logs"
CLUSTER_NAME="homelab-test-cluster"
CHECK_INTERVAL=5

# Helper functions
timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log() {
    echo -e "${CYAN}[$(timestamp)]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ [$(timestamp)]${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠️  [$(timestamp)]${NC} $1"
}

error() {
    echo -e "${RED}❌ [$(timestamp)]${NC} $1"
}

title() {
    echo
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE} $1${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
    echo
}

# Parse log files for cluster information
parse_cluster_info() {
    local log_file="$1"
    local node_name="$2"

    if [[ ! -f "$log_file" ]]; then
        warn "Log file not found: $log_file"
        return
    fi

    echo -e "${BOLD}Node: $node_name${NC}"

    # Check if node started successfully
    if grep -q "System started successfully" "$log_file" 2>/dev/null; then
        success "Node startup: OK"
    else
        warn "Node startup: PENDING or FAILED"
    fi

    # Check for clustering information
    local cluster_info=$(grep -i "cluster\|discovery\|join" "$log_file" 2>/dev/null | tail -3)
    if [[ -n "$cluster_info" ]]; then
        echo -e "${BLUE}Cluster Activity:${NC}"
        echo "$cluster_info" | sed 's/^/  /'
    fi

    # Check for errors
    local errors=$(grep -i "error\|failed\|exception" "$log_file" 2>/dev/null | tail -2)
    if [[ -n "$errors" ]]; then
        echo -e "${RED}Recent Errors:${NC}"
        echo "$errors" | sed 's/^/  /'
    fi

    # Check for network binding
    local network_info=$(grep -i "bind\|listening\|port" "$log_file" 2>/dev/null | tail -2)
    if [[ -n "$network_info" ]]; then
        echo -e "${BLUE}Network Info:${NC}"
        echo "$network_info" | sed 's/^/  /'
    fi

    echo
}

# Monitor all cluster nodes
monitor_cluster() {
    title "CLUSTER MONITORING"

    while true; do
        clear
        title "Homelab Cluster Status - $(timestamp)"

        # Check for running nodes
        local running_nodes=0
        local total_nodes=0

        for log_file in "$LOG_DIR"/*.log; do
            if [[ -f "$log_file" ]]; then
                local node_name=$(basename "$log_file" .log)
                total_nodes=$((total_nodes + 1))

                # Check if corresponding PID exists and process is running
                local pid_file="./pids/$node_name.pid"
                if [[ -f "$pid_file" ]]; then
                    local pid=$(cat "$pid_file")
                    if kill -0 "$pid" 2>/dev/null; then
                        running_nodes=$((running_nodes + 1))
                        parse_cluster_info "$log_file" "$node_name"
                    else
                        error "Node $node_name: Process not running (PID: $pid)"
                    fi
                else
                    warn "Node $node_name: No PID file found"
                fi
            fi
        done

        echo -e "${BOLD}Cluster Summary:${NC} $running_nodes/$total_nodes nodes running"

        # Network connectivity test
        test_network_connectivity

        echo
        echo -e "${YELLOW}Press Ctrl+C to stop monitoring...${NC}"
        echo -e "${YELLOW}Refreshing in $CHECK_INTERVAL seconds...${NC}"

        sleep $CHECK_INTERVAL
    done
}

# Test network connectivity between nodes
test_network_connectivity() {
    title "NETWORK CONNECTIVITY TEST"

    local ports=(4000 4001 4002 4003)
    local open_ports=0

    for port in "${ports[@]}"; do
        if command -v nc >/dev/null 2>&1; then
            if timeout 1 nc -z 127.0.0.1 "$port" 2>/dev/null; then
                success "Port $port: OPEN"
                open_ports=$((open_ports + 1))
            else
                warn "Port $port: CLOSED"
            fi
        elif command -v telnet >/dev/null 2>&1; then
            if timeout 1 telnet 127.0.0.1 "$port" 2>&1 | grep -q "Connected"; then
                success "Port $port: OPEN"
                open_ports=$((open_ports + 1))
            else
                warn "Port $port: CLOSED"
            fi
        else
            warn "No network testing tools available (nc or telnet)"
            break
        fi
    done

    echo -e "${BOLD}Network Summary:${NC} $open_ports/${#ports[@]} ports accessible"
}

# Analyze cluster logs for issues
analyze_logs() {
    title "CLUSTER LOG ANALYSIS"

    log "Analyzing logs for common issues..."

    # Check for startup issues
    echo -e "${BOLD}Startup Issues:${NC}"
    local startup_errors=$(grep -l "Failed to start\|startup failed\|configuration.*failed" "$LOG_DIR"/*.log 2>/dev/null || true)
    if [[ -n "$startup_errors" ]]; then
        for file in $startup_errors; do
            local node=$(basename "$file" .log)
            error "Node $node has startup issues"
            grep "Failed to start\|startup failed\|configuration.*failed" "$file" | head -2 | sed 's/^/  /'
        done
    else
        success "No startup issues found"
    fi

    echo

    # Check for clustering issues
    echo -e "${BOLD}Clustering Issues:${NC}"
    local cluster_errors=$(grep -l "cluster.*error\|discovery.*failed\|connection.*refused" "$LOG_DIR"/*.log 2>/dev/null || true)
    if [[ -n "$cluster_errors" ]]; then
        for file in $cluster_errors; do
            local node=$(basename "$file" .log)
            error "Node $node has clustering issues"
            grep "cluster.*error\|discovery.*failed\|connection.*refused" "$file" | head -2 | sed 's/^/  /'
        done
    else
        success "No clustering issues found"
    fi

    echo

    # Check for resource issues
    echo -e "${BOLD}Resource Issues:${NC}"
    local resource_errors=$(grep -l "memory\|disk.*full\|resource.*exceeded" "$LOG_DIR"/*.log 2>/dev/null || true)
    if [[ -n "$resource_errors" ]]; then
        for file in $resource_errors; do
            local node=$(basename "$file" .log)
            warn "Node $node may have resource issues"
            grep "memory\|disk.*full\|resource.*exceeded" "$file" | head -2 | sed 's/^/  /'
        done
    else
        success "No resource issues found"
    fi
}

# Generate cluster report
generate_report() {
    local report_file="cluster_report_$(date +%Y%m%d_%H%M%S).txt"

    title "GENERATING CLUSTER REPORT"

    {
        echo "Homelab Cluster Report"
        echo "Generated: $(timestamp)"
        echo "=================================="
        echo

        echo "CLUSTER CONFIGURATION:"
        echo "  Cluster Name: $CLUSTER_NAME"
        echo "  Log Directory: $LOG_DIR"
        echo "  Nodes Expected: coordinator, agent1, agent2, gateway"
        echo

        echo "NODE STATUS:"
        for log_file in "$LOG_DIR"/*.log; do
            if [[ -f "$log_file" ]]; then
                local node_name=$(basename "$log_file" .log)
                echo "  $node_name:"

                # Check if process is running
                local pid_file="./pids/$node_name.pid"
                if [[ -f "$pid_file" ]]; then
                    local pid=$(cat "$pid_file")
                    if kill -0 "$pid" 2>/dev/null; then
                        echo "    Status: RUNNING (PID: $pid)"
                    else
                        echo "    Status: STOPPED"
                    fi
                else
                    echo "    Status: NOT STARTED"
                fi

                # Log file stats
                local line_count=$(wc -l < "$log_file" 2>/dev/null || echo "0")
                echo "    Log Lines: $line_count"

                # Recent activity
                echo "    Recent Activity:"
                tail -3 "$log_file" 2>/dev/null | sed 's/^/      /' || echo "      No recent activity"
                echo
            fi
        done

        echo "NETWORK STATUS:"
        local ports=(4000 4001 4002 4003)
        for port in "${ports[@]}"; do
            if command -v nc >/dev/null 2>&1; then
                if timeout 1 nc -z 127.0.0.1 "$port" 2>/dev/null; then
                    echo "  Port $port: OPEN"
                else
                    echo "  Port $port: CLOSED"
                fi
            fi
        done
        echo

        echo "ERROR SUMMARY:"
        local total_errors=0
        for log_file in "$LOG_DIR"/*.log; do
            if [[ -f "$log_file" ]]; then
                local node_name=$(basename "$log_file" .log)
                local error_count=$(grep -c -i "error\|failed\|exception" "$log_file" 2>/dev/null || echo "0")
                if [[ "$error_count" -gt 0 ]]; then
                    echo "  $node_name: $error_count errors"
                    total_errors=$((total_errors + error_count))
                fi
            fi
        done

        if [[ "$total_errors" -eq 0 ]]; then
            echo "  No errors found in logs"
        else
            echo "  Total errors across cluster: $total_errors"
        fi

    } > "$report_file"

    success "Cluster report saved to: $report_file"

    # Show summary
    echo
    echo -e "${BOLD}Report Summary:${NC}"
    head -20 "$report_file"
    echo "..."
    echo -e "${BLUE}Full report available in: $report_file${NC}"
}

# Show real-time cluster activity
watch_activity() {
    title "REAL-TIME CLUSTER ACTIVITY"

    if [[ ! -d "$LOG_DIR" ]]; then
        error "Log directory not found: $LOG_DIR"
        error "Make sure to start the cluster first with: ./scripts/test-multi-node.sh start"
        exit 1
    fi

    log "Watching for cluster activity... Press Ctrl+C to stop"
    echo

    # Use tail to follow all log files
    if command -v multitail >/dev/null 2>&1; then
        multitail -ci green -cT ansi -n 20 "$LOG_DIR"/*.log
    else
        tail -f "$LOG_DIR"/*.log 2>/dev/null | while IFS= read -r line; do
            # Colorize different types of messages
            if echo "$line" | grep -q -i "error\|failed"; then
                echo -e "${RED}$line${NC}"
            elif echo "$line" | grep -q -i "success\|started\|ok"; then
                echo -e "${GREEN}$line${NC}"
            elif echo "$line" | grep -q -i "cluster\|discovery\|join"; then
                echo -e "${YELLOW}$line${NC}"
            else
                echo "$line"
            fi
        done
    fi
}

# Quick cluster health check
health_check() {
    title "CLUSTER HEALTH CHECK"

    local healthy_nodes=0
    local total_nodes=0
    local issues=()

    # Check node processes
    for pid_file in ./pids/*.pid; do
        if [[ -f "$pid_file" ]]; then
            total_nodes=$((total_nodes + 1))
            local node_name=$(basename "$pid_file" .pid)
            local pid=$(cat "$pid_file")

            if kill -0 "$pid" 2>/dev/null; then
                healthy_nodes=$((healthy_nodes + 1))
                success "Node $node_name: HEALTHY"
            else
                issues+=("Node $node_name: Process not running")
                error "Node $node_name: UNHEALTHY"
            fi
        fi
    done

    # Check network ports
    local ports=(4000 4001 4002 4003)
    local open_ports=0

    for port in "${ports[@]}"; do
        if command -v nc >/dev/null 2>&1; then
            if timeout 1 nc -z 127.0.0.1 "$port" 2>/dev/null; then
                open_ports=$((open_ports + 1))
            else
                issues+=("Port $port: Not accessible")
            fi
        fi
    done

    # Summary
    echo
    echo -e "${BOLD}Health Summary:${NC}"
    echo -e "  Nodes: $healthy_nodes/$total_nodes healthy"
    echo -e "  Ports: $open_ports/${#ports[@]} accessible"

    if [[ ${#issues[@]} -eq 0 ]]; then
        success "Cluster is healthy!"
    else
        warn "Found ${#issues[@]} issues:"
        for issue in "${issues[@]}"; do
            echo -e "    ${RED}• $issue${NC}"
        done
    fi
}

# Show help
show_help() {
    cat << EOF
Cluster Monitoring and Testing Utilities

Usage: $0 <command>

Commands:
    monitor         Monitor cluster status continuously
    analyze         Analyze logs for issues
    report          Generate detailed cluster report
    watch           Watch real-time cluster activity
    health          Quick cluster health check
    connectivity    Test network connectivity only
    help            Show this help message

Examples:
    $0 monitor          # Continuous cluster monitoring
    $0 health           # Quick health check
    $0 watch            # Follow real-time logs
    $0 report           # Generate detailed report

Note: Make sure to start the cluster first:
    ./scripts/test-multi-node.sh start

Logs Directory: $LOG_DIR/
EOF
}

# Signal handlers
trap 'log "Monitoring stopped."; exit 130' INT TERM

# Main command handling
case "${1:-help}" in
    "monitor")
        monitor_cluster
        ;;
    "analyze")
        analyze_logs
        ;;
    "report")
        generate_report
        ;;
    "watch")
        watch_activity
        ;;
    "health")
        health_check
        ;;
    "connectivity")
        test_network_connectivity
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
