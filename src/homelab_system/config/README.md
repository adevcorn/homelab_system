# Configuration Module

This module provides comprehensive configuration management for the Homelab System, handling both node-level and cluster-level settings with validation, environment overrides, and JSON serialization support.

## Module Structure

```
src/homelab_system/config/
├── README.md              # This file
├── node_config.gleam      # Individual node configuration
├── cluster_config.gleam   # Cluster-wide configuration
└── validation.gleam       # Configuration validation system
```

## Quick Start

```gleam
import homelab_system/config/node_config
import homelab_system/config/cluster_config
import homelab_system/config/validation

// Load default configurations
let node_config = node_config.default_config()
let cluster_config = cluster_config.default_config()

// Validate configurations
case node_config.validate_config(node_config) {
  Ok(Nil) -> // Configuration is valid
  Error(errors) -> // Handle validation errors
}

// Check consistency between node and cluster configs
let context = validation.default_validation_context()
case validation.validate_configs_consistency(node_config, cluster_config, context) {
  Ok(issues) -> // Check if issues list is empty
  Error(error) -> // Handle validation failure
}
```

## Key Features

### Node Configuration (`node_config.gleam`)

- **Node Identity**: Unique ID, name, and role assignment
- **Network Settings**: Bind address, ports, TLS configuration
- **Resource Limits**: Memory, CPU, disk, and timeout settings
- **Feature Flags**: Enable/disable clustering, monitoring, web interface
- **Environment Support**: Development, staging, production environments

### Cluster Configuration (`cluster_config.gleam`)

- **Cluster Identity**: Cluster ID and name
- **Service Discovery**: Static, multicast, or DNS-based discovery
- **Networking**: Port ranges, encryption, message compression
- **Consensus**: Simple, Raft, or PBFT algorithms
- **Security**: Authentication, authorization, secure communication
- **Resource Limits**: Cluster-wide resource constraints

### Validation System (`validation.gleam`)

- **Individual Validation**: Validate node or cluster configs independently
- **Consistency Checking**: Cross-configuration validation
- **Error Reporting**: Detailed validation error and warning messages
- **Validation Contexts**: Different validation rules for different environments

## Configuration Loading Priority

1. **Explicit JSON files** (highest priority)
2. **Environment variables** 
3. **Default values** (lowest priority)

## Environment Variables

### Node Configuration
- `HOMELAB_NODE_ID`: Node identifier
- `HOMELAB_NODE_NAME`: Node display name
- `HOMELAB_NODE_ROLE`: Node role (coordinator, gateway, monitor, agent)
- `HOMELAB_PORT`: Main service port
- `HOMELAB_ENVIRONMENT`: Environment (development, production, etc.)

### Cluster Configuration
- `HOMELAB_CLUSTER_ID`: Cluster identifier
- `HOMELAB_CLUSTER_NAME`: Cluster display name
- `HOMELAB_DISCOVERY_METHOD`: Service discovery method
- `HOMELAB_MAX_NODES`: Maximum cluster size

## API Reference

### Core Functions

```gleam
// Node Configuration
node_config.default_config() -> NodeConfig
node_config.from_environment() -> NodeConfig
node_config.load_config(Option(String)) -> NodeConfig
node_config.validate_config(NodeConfig) -> Result(Nil, List(String))

// Cluster Configuration  
cluster_config.default_config() -> ClusterConfig
cluster_config.from_environment() -> ClusterConfig
cluster_config.load_config(Option(String)) -> ClusterConfig
cluster_config.validate_config(ClusterConfig) -> Result(Nil, List(String))

// Validation
validation.validate_configs_consistency(
  NodeConfig, 
  ClusterConfig, 
  ValidationContext
) -> Result(List(ValidationIssue), String)
```

### Serialization

```gleam
// Convert to/from JSON
node_config.to_json(NodeConfig) -> String
node_config.from_json_string(String) -> Result(NodeConfig, String)
cluster_config.to_json(ClusterConfig) -> String
cluster_config.from_json_string(String) -> Result(ClusterConfig, String)
```

## Testing

The configuration module has comprehensive test coverage:

```
test/homelab_system/config/
├── node_config_test.gleam      # Node configuration tests
├── cluster_config_test.gleam   # Cluster configuration tests
├── validation_test.gleam       # Validation system tests
└── integration_test.gleam      # Integration tests
```

Run tests with:
```bash
gleam test
```

## Documentation

For detailed documentation, see:
- [Configuration System Guide](../../../docs/CONFIGURATION.md)
- Individual module documentation in source files
- Test files for usage examples

## Best Practices

1. **Always validate configurations** before using them
2. **Check consistency** between node and cluster configs
3. **Use environment-specific settings** for different deployment stages
4. **Enable debug mode** during development for detailed logging
5. **Backup configuration files** in production environments

## Common Patterns

### Environment-Based Configuration

```gleam
pub fn load_for_environment(env: String) -> #(NodeConfig, ClusterConfig) {
  let node_config = case env {
    "production" -> create_production_node_config()
    "staging" -> create_staging_node_config()
    _ -> node_config.default_config()
  }
  
  let cluster_config = case env {
    "production" -> create_production_cluster_config()
    "staging" -> create_staging_cluster_config()
    _ -> cluster_config.default_config()
  }
  
  #(node_config, cluster_config)
}
```

### Safe Configuration Loading

```gleam
pub fn safe_load_config() -> Result(#(NodeConfig, ClusterConfig), String) {
  let node_config = node_config.from_environment()
  let cluster_config = cluster_config.from_environment()
  
  // Validate individual configs
  case node_config.validate_config(node_config) {
    Error(errors) -> Error("Node config errors: " <> string.join(errors, ", "))
    Ok(Nil) -> case cluster_config.validate_config(cluster_config) {
      Error(errors) -> Error("Cluster config errors: " <> string.join(errors, ", "))
      Ok(Nil) -> {
        // Check consistency
        let context = validation.default_validation_context()
        case validation.validate_configs_consistency(node_config, cluster_config, context) {
          Ok(issues) -> case validation.has_errors(issues) {
            True -> Error("Configuration consistency errors found")
            False -> Ok(#(node_config, cluster_config))
          }
          Error(error) -> Error("Validation failed: " <> error)
        }
      }
    }
  }
}
```
