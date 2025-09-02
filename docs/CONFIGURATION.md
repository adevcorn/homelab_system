# Configuration Management System

The Homelab System uses a comprehensive configuration management system that handles both node-level and cluster-level settings with validation, environment overrides, and JSON serialization support.

## Table of Contents

- [Overview](#overview)
- [Configuration Types](#configuration-types)
- [Node Configuration](#node-configuration)
- [Cluster Configuration](#cluster-configuration)
- [Validation System](#validation-system)
- [Environment Variables](#environment-variables)
- [JSON Configuration Files](#json-configuration-files)
- [Configuration Loading Priority](#configuration-loading-priority)
- [API Reference](#api-reference)
- [Examples](#examples)
- [Best Practices](#best-practices)

## Overview

The configuration system is built with three main components:

1. **Node Configuration** (`homelab_system/config/node_config`): Individual node settings
2. **Cluster Configuration** (`homelab_system/config/cluster_config`): Cluster-wide settings
3. **Validation System** (`homelab_system/config/validation`): Configuration validation and consistency checks

The system supports multiple configuration sources with a clear priority order:
1. JSON configuration files
2. Environment variables
3. Default values

## Configuration Types

### Node Configuration

Node configuration defines settings for individual nodes in the homelab cluster:

```gleam
pub type NodeConfig {
  NodeConfig(
    node_id: String,
    node_name: String,
    role: NodeRole,
    capabilities: List(String),
    network: NetworkConfig,
    resources: ResourceConfig,
    features: FeatureConfig,
    environment: String,
    debug: Bool,
    metadata: Dict(String, String),
  )
}
```

### Cluster Configuration

Cluster configuration defines settings for the entire cluster:

```gleam
pub type ClusterConfig {
  ClusterConfig(
    cluster_id: String,
    cluster_name: String,
    environment: String,
    discovery: DiscoveryConfig,
    networking: ClusterNetworkConfig,
    coordination: CoordinationConfig,
    security: SecurityConfig,
    features: ClusterFeatureConfig,
    limits: ClusterLimits,
  )
}
```

## Node Configuration

### Node Roles

The system supports several node roles:

- **Coordinator**: Cluster coordination and management
- **Gateway**: External communication and API endpoints
- **Monitor**: System monitoring and health checks
- **Agent**: Specialized agents with subtypes:
  - `Generic`: General-purpose agent
  - `Monitoring`: Monitoring-specific agent
  - `Storage`: Storage management agent
  - `Compute`: Compute task agent
  - `Network`: Network management agent

### Network Configuration

```gleam
pub type NetworkConfig {
  NetworkConfig(
    bind_address: String,        // Default: "0.0.0.0"
    port: Int,                   // Default: 4000
    discovery_port: Option(Int), // Default: Some(4001)
    external_host: Option(String),
    tls_enabled: Bool,           // Default: False
    max_connections: Int,        // Default: 100
  )
}
```

### Resource Configuration

```gleam
pub type ResourceConfig {
  ResourceConfig(
    max_memory_mb: Int,          // Default: 512
    max_cpu_percent: Int,        // Default: 80
    disk_space_mb: Int,          // Default: 1024
    connection_timeout_ms: Int,  // Default: 30000
    request_timeout_ms: Int,     // Default: 5000
  )
}
```

### Feature Configuration

```gleam
pub type FeatureConfig {
  FeatureConfig(
    clustering: Bool,          // Default: True
    metrics_collection: Bool,  // Default: True
    health_checks: Bool,       // Default: True
    web_interface: Bool,       // Default: True
    api_endpoints: Bool,       // Default: True
    auto_discovery: Bool,      // Default: True
    load_balancing: Bool,      // Default: False
  )
}
```

## Cluster Configuration

### Discovery Methods

- **Static**: Predefined list of bootstrap nodes
- **Multicast**: UDP multicast discovery
- **DNS**: DNS-based service discovery

### Consensus Algorithms

- **Simple**: Basic leader election
- **Raft**: Raft consensus algorithm
- **PBFT**: Practical Byzantine Fault Tolerance

## Validation System

The validation system provides comprehensive configuration validation:

### Validation Context

```gleam
pub type ValidationContext {
  ValidationContext(
    strict_mode: Bool,
    environment: String,
    check_port_conflicts: Bool,
    check_resource_limits: Bool,
    check_security_settings: Bool,
  )
}
```

### Validation Functions

- `validate_config(config)`: Validates individual configurations
- `validate_configs_consistency(node_config, cluster_config, context)`: Cross-configuration validation
- `has_errors(issues)`: Checks if validation issues contain errors
- `has_warnings(issues)`: Checks if validation issues contain warnings

## Environment Variables

### Node Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HOMELAB_NODE_ID` | Unique node identifier | "homelab-node-1" |
| `HOMELAB_NODE_NAME` | Human-readable node name | "homelab-node" |
| `HOMELAB_NODE_ROLE` | Node role | "agent" |
| `HOMELAB_NODE_CAPABILITIES` | Comma-separated capabilities | "health_check,metrics,monitoring" |
| `HOMELAB_BIND_ADDRESS` | Network bind address | "0.0.0.0" |
| `HOMELAB_PORT` | Main service port | "4000" |
| `HOMELAB_DISCOVERY_PORT` | Discovery service port | "4001" |
| `HOMELAB_ENVIRONMENT` | Environment name | "development" |
| `HOMELAB_DEBUG` | Debug mode | "true" |

### Cluster Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HOMELAB_CLUSTER_ID` | Unique cluster identifier | "homelab-cluster-1" |
| `HOMELAB_CLUSTER_NAME` | Human-readable cluster name | "homelab-cluster" |
| `HOMELAB_DISCOVERY_METHOD` | Discovery method | "static" |
| `HOMELAB_BOOTSTRAP_NODES` | Bootstrap nodes list | "localhost:4001" |
| `HOMELAB_MAX_NODES` | Maximum cluster nodes | "10" |
| `HOMELAB_CONSENSUS_ALGORITHM` | Consensus algorithm | "simple" |

## JSON Configuration Files

### Node Configuration Example

```json
{
  "node_id": "node-001",
  "node_name": "primary-node",
  "role": "coordinator",
  "capabilities": ["health_check", "metrics", "coordination"],
  "network": {
    "bind_address": "0.0.0.0",
    "port": 4000,
    "discovery_port": 4001,
    "tls_enabled": false,
    "max_connections": 100
  },
  "resources": {
    "max_memory_mb": 1024,
    "max_cpu_percent": 80,
    "disk_space_mb": 2048,
    "connection_timeout_ms": 30000,
    "request_timeout_ms": 5000
  },
  "features": {
    "clustering": true,
    "metrics_collection": true,
    "health_checks": true,
    "web_interface": true,
    "api_endpoints": true,
    "auto_discovery": true,
    "load_balancing": false
  },
  "environment": "production",
  "debug": false,
  "metadata": {
    "version": "1.1.0",
    "deployment": "kubernetes",
    "datacenter": "us-west-2"
  }
}
```

### Cluster Configuration Example

```json
{
  "cluster_id": "homelab-prod",
  "cluster_name": "Production Homelab",
  "environment": "production",
  "discovery": {
    "method": "static",
    "bootstrap_nodes": ["node1:4001", "node2:4001", "node3:4001"],
    "discovery_port": 4001,
    "heartbeat_interval_ms": 5000,
    "timeout_ms": 30000,
    "retry_attempts": 3
  },
  "networking": {
    "cluster_port_range_start": 5000,
    "cluster_port_range_end": 5999,
    "inter_node_encryption": true,
    "message_compression": true,
    "max_message_size_kb": 1024
  },
  "coordination": {
    "election_timeout_ms": 10000,
    "heartbeat_timeout_ms": 5000,
    "leader_lease_duration_ms": 30000,
    "quorum_size": 3,
    "split_brain_protection": true,
    "consensus_algorithm": "raft"
  },
  "security": {
    "authentication_enabled": true,
    "authorization_enabled": true,
    "secure_communication": true,
    "certificate_path": "/etc/homelab/certs/cluster.pem"
  },
  "limits": {
    "max_nodes": 50,
    "max_tasks_per_node": 200,
    "max_memory_per_cluster_gb": 128,
    "max_storage_per_cluster_gb": 10000,
    "connection_pool_size": 100
  }
}
```

## Configuration Loading Priority

The system loads configuration in the following priority order (highest to lowest):

1. **JSON Configuration File**: Explicitly provided JSON file
2. **Environment Variables**: System environment variables
3. **Default Values**: Built-in default configuration

### Loading Functions

```gleam
// Load with explicit JSON file
let config = node_config.load_config(Some("/path/to/config.json"))

// Load from environment variables (with defaults)
let config = node_config.from_environment()

// Load default configuration
let config = node_config.default_config()
```

## API Reference

### Node Configuration Functions

```gleam
// Create default configuration
node_config.default_config() -> NodeConfig

// Load from environment variables
node_config.from_environment() -> NodeConfig

// Load with optional JSON file
node_config.load_config(json_file: Option(String)) -> NodeConfig

// Serialize to JSON
node_config.to_json(config: NodeConfig) -> String

// Deserialize from JSON
node_config.from_json_string(json: String) -> Result(NodeConfig, String)

// Validate configuration
node_config.validate_config(config: NodeConfig) -> Result(Nil, List(String))

// Generate summary
node_config.get_config_summary(config: NodeConfig) -> String
```

### Cluster Configuration Functions

```gleam
// Create default configuration
cluster_config.default_config() -> ClusterConfig

// Load from environment variables
cluster_config.from_environment() -> ClusterConfig

// Load with optional JSON file
cluster_config.load_config(json_file: Option(String)) -> ClusterConfig

// Serialize to JSON
cluster_config.to_json(config: ClusterConfig) -> String

// Deserialize from JSON
cluster_config.from_json_string(json: String) -> Result(ClusterConfig, String)

// Validate configuration
cluster_config.validate_config(config: ClusterConfig) -> Result(Nil, List(String))

// Generate summary
cluster_config.get_config_summary(config: ClusterConfig) -> String
```

### Validation Functions

```gleam
// Create validation context
validation.default_validation_context() -> ValidationContext
validation.strict_validation_context() -> ValidationContext

// Cross-configuration validation
validation.validate_configs_consistency(
  node_config: NodeConfig,
  cluster_config: ClusterConfig,
  context: ValidationContext,
) -> Result(List(ValidationIssue), String)

// Check validation results
validation.has_errors(issues: List(ValidationIssue)) -> Bool
validation.has_warnings(issues: List(ValidationIssue)) -> Bool
```

## Examples

### Basic Setup

```gleam
import homelab_system/config/node_config
import homelab_system/config/cluster_config
import homelab_system/config/validation

pub fn setup_configuration() {
  // Load configurations
  let node_config = node_config.from_environment()
  let cluster_config = cluster_config.from_environment()
  
  // Validate individual configurations
  case node_config.validate_config(node_config) {
    Ok(Nil) -> Nil
    Error(errors) -> {
      // Handle validation errors
      io.println("Node configuration errors:")
      list.each(errors, io.println)
      panic
    }
  }
  
  case cluster_config.validate_config(cluster_config) {
    Ok(Nil) -> Nil
    Error(errors) -> {
      // Handle validation errors
      io.println("Cluster configuration errors:")
      list.each(errors, io.println)
      panic
    }
  }
  
  // Validate consistency
  let validation_context = validation.default_validation_context()
  case validation.validate_configs_consistency(
    node_config,
    cluster_config,
    validation_context,
  ) {
    Ok(issues) -> {
      case validation.has_errors(issues) {
        True -> {
          io.println("Configuration consistency errors found")
          panic
        }
        False -> {
          case validation.has_warnings(issues) {
            True -> io.println("Configuration warnings found")
            False -> io.println("Configuration validated successfully")
          }
        }
      }
    }
    Error(error) -> {
      io.println("Validation failed: " <> error)
      panic
    }
  }
  
  #(node_config, cluster_config)
}
```

### Custom Configuration

```gleam
pub fn create_custom_configuration() {
  // Create a custom node configuration
  let node_config = node_config.NodeConfig(
    ..node_config.default_config(),
    node_id: "custom-node-001",
    role: node_config.Coordinator,
    network: node_config.NetworkConfig(
      ..node_config.default_config().network,
      port: 8080,
      tls_enabled: True,
    ),
    environment: "production",
    debug: False,
  )
  
  // Create a custom cluster configuration
  let cluster_config = cluster_config.ClusterConfig(
    ..cluster_config.default_config(),
    cluster_name: "Production Cluster",
    discovery: cluster_config.DiscoveryConfig(
      ..cluster_config.default_config().discovery,
      method: cluster_config.DNS,
    ),
    security: cluster_config.SecurityConfig(
      ..cluster_config.default_config().security,
      authentication_enabled: True,
      secure_communication: True,
    ),
    environment: "production",
  )
  
  #(node_config, cluster_config)
}
```

### Configuration Serialization

```gleam
pub fn save_and_load_configuration() {
  // Create configuration
  let node_config = node_config.default_config()
  
  // Serialize to JSON
  let json_string = node_config.to_json(node_config)
  
  // Save to file (using simplifile)
  case simplifile.write(json_string, to: "node_config.json") {
    Ok(_) -> io.println("Configuration saved")
    Error(_) -> io.println("Failed to save configuration")
  }
  
  // Load from file
  case simplifile.read("node_config.json") {
    Ok(json_content) -> {
      case node_config.from_json_string(json_content) {
        Ok(loaded_config) -> {
          io.println("Configuration loaded successfully")
          loaded_config
        }
        Error(error) -> {
          io.println("Failed to parse configuration: " <> error)
          node_config.default_config()
        }
      }
    }
    Error(_) -> {
      io.println("Failed to read configuration file")
      node_config.default_config()
    }
  }
}
```

## Best Practices

### 1. Environment-Specific Configuration

Use different environment settings for development, staging, and production:

```gleam
pub fn get_environment_config() {
  case get_environment() {
    "production" -> create_production_config()
    "staging" -> create_staging_config()
    _ -> create_development_config()
  }
}
```

### 2. Validation Before Use

Always validate configurations before using them:

```gleam
pub fn safe_config_load() {
  let config = node_config.from_environment()
  
  case node_config.validate_config(config) {
    Ok(Nil) -> Ok(config)
    Error(errors) -> Error("Invalid configuration: " <> string.join(errors, ", "))
  }
}
```

### 3. Configuration Consistency

Always check consistency between node and cluster configurations:

```gleam
pub fn ensure_consistency(node_config, cluster_config) {
  let context = validation.strict_validation_context()
  
  case validation.validate_configs_consistency(node_config, cluster_config, context) {
    Ok(issues) -> {
      case validation.has_errors(issues) {
        True -> Error("Configuration consistency errors")
        False -> Ok(#(node_config, cluster_config))
      }
    }
    Error(error) -> Error("Validation failed: " <> error)
  }
}
```

### 4. Secure Configuration

For production environments:

- Enable TLS/SSL for network communication
- Use authentication and authorization
- Set appropriate resource limits
- Use secure consensus algorithms
- Regularly validate and audit configurations

### 5. Monitoring Configuration

- Log configuration changes
- Monitor for configuration drift
- Set up alerts for validation failures
- Regularly backup configuration files

## Troubleshooting

### Common Issues

1. **Port Conflicts**: Ensure node and cluster ports don't conflict
2. **Environment Mismatches**: Node and cluster environments must match
3. **Invalid Resource Limits**: Memory, CPU, and disk limits must be positive
4. **Missing Bootstrap Nodes**: Static discovery requires valid bootstrap nodes
5. **JSON Parse Errors**: Validate JSON syntax before loading

### Debug Mode

Enable debug mode for detailed configuration information:

```bash
export HOMELAB_DEBUG=true
```

This will provide detailed logging during configuration loading and validation.