# Multi-Node Testing Scripts

This directory contains comprehensive testing scripts for the Homelab System's distributed clustering functionality. These scripts help you test node discovery, cluster formation, and inter-node communication.

## Quick Start

```bash
# Start a 4-node cluster
./scripts/test-multi-node.sh start

# Monitor cluster health
./scripts/monitor-cluster.sh health

# Watch real-time activity
./scripts/monitor-cluster.sh watch

# Stop the cluster
./scripts/test-multi-node.sh stop
```

## Scripts Overview

### 🚀 `test-multi-node.sh`
**Main cluster management script**

Manages a multi-node test cluster with different node types:
- **coordinator** (port 4000) - Cluster coordination
- **agent1** (port 4001) - Monitoring agent  
- **agent2** (port 4002) - Storage agent
- **gateway** (port 4003) - Gateway node

**Commands:**
```bash
./scripts/test-multi-node.sh start     # Start all nodes
./scripts/test-multi-node.sh stop      # Stop all nodes  
./scripts/test-multi-node.sh restart   # Restart cluster
./scripts/test-multi-node.sh status    # Show node status
./scripts/test-multi-node.sh logs      # Follow all logs
./scripts/test-multi-node.sh logs coordinator  # Follow specific node
./scripts/test-multi-node.sh test      # Test connectivity
./scripts/test-multi-node.sh cleanup   # Clean up files
```

### 📊 `monitor-cluster.sh`
**Cluster monitoring and analysis**

Provides detailed monitoring, health checks, and log analysis:

**Commands:**
```bash
./scripts/monitor-cluster.sh monitor       # Continuous monitoring
./scripts/monitor-cluster.sh health        # Quick health check
./scripts/monitor-cluster.sh analyze       # Analyze logs for issues
./scripts/monitor-cluster.sh report        # Generate detailed report
./scripts/monitor-cluster.sh watch         # Real-time log following
./scripts/monitor-cluster.sh connectivity  # Test network connectivity
```

### 🎭 `demo-cluster.sh`
**Interactive demonstration**

Runs a complete guided demo of multi-node functionality:

```bash
./scripts/demo-cluster.sh              # Run interactive demo
./scripts/demo-cluster.sh --help       # Show demo help
```

The demo covers:
1. Cluster startup and initialization
2. Node discovery monitoring
3. Health checks and connectivity tests
4. Real-time log analysis
5. Failure scenario simulation
6. Report generation
7. Graceful shutdown

## Cluster Configuration

### Default Node Setup

| Node | Role | Port | Agent Type | Purpose |
|------|------|------|------------|---------|
| coordinator | Coordinator | 4000 | - | Cluster coordination |
| agent1 | Agent | 4001 | Monitoring | System monitoring |
| agent2 | Agent | 4002 | Storage | Data storage |
| gateway | Gateway | 4003 | - | External access |

### Environment Variables

Each node is started with specific environment variables:

```bash
# Node Identity
NODE_ID="coordinator"               # Unique node identifier
NODE_NAME="homelab-coordinator"     # Human-readable name
NODE_ROLE="Coordinator"             # Node role type

# Network Configuration
BIND_PORT="4000"                    # Main service port
BIND_ADDRESS="127.0.0.1"           # Bind address
DISCOVERY_PORT="5000"               # Discovery service port

# Cluster Settings
CLUSTER_NAME="homelab-test-cluster" # Cluster identifier
CLUSTERING_ENABLED="true"           # Enable clustering
DISCOVERY_METHOD="multicast"        # Discovery method

# Features
WEB_INTERFACE_ENABLED="true"        # Enable web UI
DEBUG_MODE="true"                   # Enable debug logging
ENVIRONMENT="testing"               # Environment type
```

## File Structure

```
logs/                    # Node log files
├── coordinator.log      # Coordinator logs
├── agent1.log          # Agent1 logs
├── agent2.log          # Agent2 logs
└── gateway.log         # Gateway logs

pids/                   # Process ID files
├── coordinator.pid     # Coordinator PID
├── agent1.pid         # Agent1 PID
├── agent2.pid         # Agent2 PID
└── gateway.pid        # Gateway PID

cluster_report_*.txt    # Generated reports
```

## Testing Scenarios

### Basic Cluster Test
```bash
# 1. Start cluster
./scripts/test-multi-node.sh start

# 2. Verify all nodes are running
./scripts/test-multi-node.sh status

# 3. Check health
./scripts/monitor-cluster.sh health

# 4. Stop cluster
./scripts/test-multi-node.sh stop
```

### Node Discovery Test
```bash
# 1. Start coordinator first
NODE_ID="coordinator" gleam run &

# 2. Start agents (they should discover coordinator)
NODE_ID="agent1" BIND_PORT="4001" gleam run &
NODE_ID="agent2" BIND_PORT="4002" gleam run &

# 3. Monitor discovery in logs
./scripts/monitor-cluster.sh watch
```

### Failure Recovery Test
```bash
# 1. Start full cluster
./scripts/test-multi-node.sh start

# 2. Kill one node
kill $(cat pids/agent1.pid)

# 3. Monitor cluster response
./scripts/monitor-cluster.sh monitor

# 4. Restart failed node
NODE_ID="agent1" BIND_PORT="4001" gleam run &
```

## Monitoring and Analysis

### Real-time Monitoring
The monitoring script provides several views:

**Health Dashboard:**
- Node process status
- Network connectivity
- Recent log activity
- Error detection

**Log Analysis:**
- Startup issues detection
- Clustering problems
- Resource usage warnings
- Communication failures

**Network Testing:**
- Port accessibility checks
- Connection timeouts
- Service availability

### Generated Reports

Reports include:
- Node status summary
- Network connectivity matrix
- Error count and categorization
- Recent activity timeline
- Configuration summary
- Troubleshooting recommendations

## Customization

### Adding New Nodes

Edit `test-multi-node.sh` and add to the `NODES` array:

```bash
declare -A NODES=(
    ["coordinator"]="Coordinator 4000"
    ["agent1"]="Agent 4001 Monitoring"
    ["agent2"]="Agent 4002 Storage"
    ["gateway"]="Gateway 4003"
    ["newnode"]="Agent 4004 Compute"    # Add new node
)
```

### Changing Discovery Method

Modify the environment variables in the start functions:

```bash
export DISCOVERY_METHOD="dns"           # Use DNS discovery
export DISCOVERY_NODES="node1,node2"   # Static node list
export MULTICAST_GROUP="224.0.0.251"   # Multicast group
```

### Custom Port Ranges

Update the port assignments:

```bash
BASE_PORT=5000                          # Start from port 5000
declare -A NODES=(
    ["coordinator"]="Coordinator 5000"
    ["agent1"]="Agent 5001 Monitoring"
    # ...
)
```

## Troubleshooting

### Common Issues

**Nodes fail to start:**
- Check if ports are already in use: `netstat -tulpn | grep :4000`
- Verify system compiles: `gleam check`
- Check log files for specific errors

**Nodes don't discover each other:**
- Verify same cluster name across nodes
- Check network connectivity between nodes
- Ensure discovery ports are accessible
- Review multicast/DNS configuration

**High resource usage:**
- Monitor with: `./scripts/monitor-cluster.sh monitor`
- Check for memory leaks in logs
- Reduce logging verbosity
- Limit number of concurrent nodes

### Log Analysis

Common log patterns to look for:

```bash
# Successful startup
grep "System started successfully" logs/*.log

# Clustering activity  
grep -i "cluster\|discovery\|join" logs/*.log

# Error detection
grep -i "error\|failed\|exception" logs/*.log

# Network issues
grep -i "connection\|timeout\|refused" logs/*.log
```

### Performance Monitoring

```bash
# Node resource usage
ps aux | grep gleam

# Port usage
netstat -tulpn | grep :400[0-3]

# Log file sizes
du -sh logs/*.log

# Process memory usage
pmap $(cat pids/*.pid) | tail -1
```

## Development

### Running Tests Manually

```bash
# Set environment for specific node
export NODE_ID="test-node"
export BIND_PORT="4010"
export CLUSTER_NAME="test-cluster"

# Run single node
gleam run

# Or run with specific config
NODE_ID="custom" BIND_PORT="4020" gleam run
```

### Debugging Tips

1. **Enable debug logging:** Set `DEBUG_MODE="true"`
2. **Use specific log levels:** Check `logging.gleam` for level controls
3. **Monitor network traffic:** Use `tcpdump` or `wireshark`
4. **Check process communication:** Use `strace` or `ltrace`

### Contributing

To add new testing scenarios:

1. Create new functions in the appropriate script
2. Add command-line options for new scenarios
3. Update the help text and documentation
4. Test with different node configurations
5. Add error handling and cleanup

## Requirements

- Gleam runtime environment
- Bash shell (4.0+)
- Network tools: `nc` (netcat) or `telnet`
- Optional: `multitail` for better log viewing
- Sufficient ports available (4000-4003, 5000-5003)

## Security Notes

These scripts are designed for **testing only**:

- Bind to localhost (127.0.0.1) by default
- Use unencrypted communication
- No authentication between nodes
- Debug logging may expose sensitive data

For production use:
- Configure proper network security
- Enable TLS/encryption
- Implement authentication
- Review and secure log output
- Use firewalls and network isolation

---

For more information about the Homelab System architecture, see the main project documentation.