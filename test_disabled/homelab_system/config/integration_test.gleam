//// Configuration System Integration Test Module
////
//// This module contains comprehensive integration tests for the configuration
//// management system, testing the interaction between node configuration,
//// cluster configuration, and validation systems working together.

import gleam/list
import gleam/option.{None}
import gleam/string
import gleeunit
import gleeunit/should

import homelab_system/config/cluster_config
import homelab_system/config/node_config
import homelab_system/config/validation

pub fn main() {
  gleeunit.main()
}

// Test complete configuration system initialization
pub fn full_system_initialization_test() {
  // Initialize node configuration
  let node_config = node_config.default_config()

  // Initialize cluster configuration
  let cluster_config = cluster_config.default_config()

  // Validate both configurations
  case node_config.validate_config(node_config) {
    Ok(Nil) -> Nil
    Error(_) -> should.fail()
  }

  case cluster_config.validate_config(cluster_config) {
    Ok(Nil) -> Nil
    Error(_) -> should.fail()
  }

  // Test configuration consistency
  let validation_context = validation.default_validation_context()

  case
    validation.validate_configs_consistency(
      node_config,
      cluster_config,
      validation_context,
    )
  {
    Ok(issues) -> {
      // Empty issues list means no problems
      should.be_true(issues == [])
    }
    Error(_) -> should.fail()
  }
}

// Test configuration system with environment overrides
pub fn environment_override_integration_test() {
  // Load configurations from environment (which will use defaults)
  let node_config = node_config.from_environment()
  let cluster_config = cluster_config.from_environment()

  // Both should be valid
  case node_config.validate_config(node_config) {
    Ok(Nil) -> Nil
    Error(_) -> should.fail()
  }

  case cluster_config.validate_config(cluster_config) {
    Ok(Nil) -> Nil
    Error(_) -> should.fail()
  }

  // Should be consistent with each other
  let validation_context = validation.default_validation_context()
  case
    validation.validate_configs_consistency(
      node_config,
      cluster_config,
      validation_context,
    )
  {
    Ok(issues) -> {
      // Empty issues list means no problems
      should.be_true(issues == [])
    }
    Error(_) -> should.fail()
  }
}

// Test configuration serialization and deserialization integration
pub fn serialization_integration_test() {
  let original_node_config = node_config.default_config()
  let original_cluster_config = cluster_config.default_config()

  // Serialize to JSON
  let node_json = node_config.to_json(original_node_config)
  let cluster_json = cluster_config.to_json(original_cluster_config)

  // Both JSON strings should be valid
  should.be_true(node_json != "")
  should.be_true(cluster_json != "")
  should.be_true(string.starts_with(node_json, "{"))
  should.be_true(string.ends_with(node_json, "}"))
  should.be_true(string.starts_with(cluster_json, "{"))
  should.be_true(string.ends_with(cluster_json, "}"))

  // Deserialize back (currently returns defaults)
  case node_config.from_json_string(node_json) {
    Ok(parsed_node) -> {
      case cluster_config.from_json_string(cluster_json) {
        Ok(parsed_cluster) -> {
          // Validate parsed configurations
          case node_config.validate_config(parsed_node) {
            Ok(Nil) -> Nil
            Error(_) -> should.fail()
          }

          case cluster_config.validate_config(parsed_cluster) {
            Ok(Nil) -> Nil
            Error(_) -> should.fail()
          }
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

// Test configuration validation with multiple error scenarios
pub fn comprehensive_validation_integration_test() {
  // Create a node config with multiple issues
  let invalid_node_config =
    node_config.NodeConfig(
      ..node_config.default_config(),
      node_id: "",
      // Empty ID
      network: node_config.NetworkConfig(
        ..node_config.default_config().network,
        port: 70_000,
        // Invalid port
      ),
      resources: node_config.ResourceConfig(
        ..node_config.default_config().resources,
        max_memory_mb: -100,
        // Invalid memory
      ),
    )

  // Create a cluster config with multiple issues
  let invalid_cluster_config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      cluster_id: "",
      // Empty ID
      cluster_name: "",
      // Empty name
      discovery: cluster_config.DiscoveryConfig(
        ..cluster_config.default_config().discovery,
        discovery_port: 0,
        // Invalid port
      ),
      limits: cluster_config.ClusterLimits(
        ..cluster_config.default_config().limits,
        max_nodes: -5,
        // Invalid limit
      ),
    )

  // Validate node config should return errors
  case node_config.validate_config(invalid_node_config) {
    Ok(Nil) -> should.fail()
    // Should have errors
    Error(errors) -> {
      should.be_true(list.length(errors) > 0)
      should.be_true(list.contains(errors, "Node ID cannot be empty"))
    }
  }

  // Validate cluster config should return errors
  case cluster_config.validate_config(invalid_cluster_config) {
    Ok(Nil) -> should.fail()
    // Should have errors
    Error(errors) -> {
      should.be_true(list.length(errors) > 0)
      should.be_true(list.contains(errors, "Cluster ID cannot be empty"))
    }
  }
}

// Test configuration loading priority integration
pub fn configuration_loading_priority_test() {
  // Test node config loading with different methods
  let default_node = node_config.default_config()
  let env_node = node_config.from_environment()
  let loaded_node = node_config.load_config(None)

  // All should be valid
  case node_config.validate_config(default_node) {
    Ok(Nil) -> Nil
    Error(_) -> should.fail()
  }

  case node_config.validate_config(env_node) {
    Ok(Nil) -> Nil
    Error(_) -> should.fail()
  }

  case node_config.validate_config(loaded_node) {
    Ok(Nil) -> Nil
    Error(_) -> should.fail()
  }

  // Test cluster config loading with different methods
  let default_cluster = cluster_config.default_config()
  let env_cluster = cluster_config.from_environment()
  let loaded_cluster = cluster_config.load_config(None)

  // All should be valid
  case cluster_config.validate_config(default_cluster) {
    Ok(Nil) -> Nil
    Error(_) -> should.fail()
  }

  case cluster_config.validate_config(env_cluster) {
    Ok(Nil) -> Nil
    Error(_) -> should.fail()
  }

  case cluster_config.validate_config(loaded_cluster) {
    Ok(Nil) -> Nil
    Error(_) -> should.fail()
  }
}

// Test configuration summaries integration
pub fn configuration_summaries_integration_test() {
  let node_config = node_config.default_config()
  let cluster_config = cluster_config.default_config()

  let node_summary = node_config.get_config_summary(node_config)
  let cluster_summary = cluster_config.get_config_summary(cluster_config)

  // Summaries should contain expected information
  should.be_true(string.contains(node_summary, "Node Configuration Summary:"))
  should.be_true(string.contains(node_summary, "Node ID:"))
  should.be_true(string.contains(node_summary, "Role:"))
  should.be_true(string.contains(node_summary, "Environment:"))

  should.be_true(string.contains(
    cluster_summary,
    "Cluster Configuration Summary:",
  ))
  should.be_true(string.contains(cluster_summary, "Cluster ID:"))
  should.be_true(string.contains(cluster_summary, "Discovery Method:"))
  should.be_true(string.contains(cluster_summary, "Environment:"))

  // Both configs should have matching environments
  should.be_true(string.contains(node_summary, "development"))
  should.be_true(string.contains(cluster_summary, "development"))
}

// Test validation system integration with different contexts
pub fn validation_system_integration_test() {
  let node_config = node_config.default_config()
  let cluster_config = cluster_config.default_config()

  // Test with default validation context
  let default_context = validation.default_validation_context()
  case
    validation.validate_configs_consistency(
      node_config,
      cluster_config,
      default_context,
    )
  {
    Ok(issues) -> {
      // Empty issues list means no problems
      should.be_true(issues == [])
    }
    Error(_) -> should.fail()
  }

  // Test with strict validation context
  let strict_context = validation.strict_validation_context()
  case
    validation.validate_configs_consistency(
      node_config,
      cluster_config,
      strict_context,
    )
  {
    Ok(issues) -> {
      // Empty issues list means no problems
      should.be_true(issues == [])
    }
    Error(_) -> should.fail()
  }
}

// Test configuration system with port conflicts
pub fn port_conflict_integration_test() {
  // Create configs that would have port conflicts
  let node_with_port_4001 =
    node_config.NodeConfig(
      ..node_config.default_config(),
      network: node_config.NetworkConfig(
        ..node_config.default_config().network,
        port: 4001,
      ),
    )

  let cluster_with_port_4001 =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      discovery: cluster_config.DiscoveryConfig(
        ..cluster_config.default_config().discovery,
        discovery_port: 4001,
      ),
    )

  // Individual configs should be valid
  case node_config.validate_config(node_with_port_4001) {
    Ok(Nil) -> Nil
    Error(_) -> should.fail()
  }

  case cluster_config.validate_config(cluster_with_port_4001) {
    Ok(Nil) -> Nil
    Error(_) -> should.fail()
  }

  // But together they should create a validation issue
  let validation_context = validation.default_validation_context()
  case
    validation.validate_configs_consistency(
      node_with_port_4001,
      cluster_with_port_4001,
      validation_context,
    )
  {
    Ok(issues) -> {
      // Should have validation issues for port conflict
      should.be_true(list.length(issues) > 0)
    }
    Error(_) -> should.fail()
  }
}

// Test environment mismatch detection
pub fn environment_mismatch_integration_test() {
  // Create configs with different environments
  let node_dev =
    node_config.NodeConfig(
      ..node_config.default_config(),
      environment: "development",
    )

  let cluster_prod =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      environment: "production",
    )

  // Individual configs should be valid
  case node_config.validate_config(node_dev) {
    Ok(Nil) -> Nil
    Error(_) -> should.fail()
  }

  case cluster_config.validate_config(cluster_prod) {
    Ok(Nil) -> Nil
    Error(_) -> should.fail()
  }

  // But together they should create a validation issue
  let validation_context = validation.default_validation_context()
  case
    validation.validate_configs_consistency(
      node_dev,
      cluster_prod,
      validation_context,
    )
  {
    Ok(issues) -> {
      // Should have validation issues for environment mismatch
      should.be_true(list.length(issues) > 0)
    }
    Error(_) -> should.fail()
  }
}

// Test complete configuration lifecycle
pub fn configuration_lifecycle_integration_test() {
  // 1. Create default configurations
  let initial_node = node_config.default_config()
  let initial_cluster = cluster_config.default_config()

  // 2. Validate initial configurations
  case node_config.validate_config(initial_node) {
    Ok(Nil) -> Nil
    Error(_) -> should.fail()
  }

  case cluster_config.validate_config(initial_cluster) {
    Ok(Nil) -> Nil
    Error(_) -> should.fail()
  }

  // 3. Check consistency
  let validation_context = validation.default_validation_context()
  case
    validation.validate_configs_consistency(
      initial_node,
      initial_cluster,
      validation_context,
    )
  {
    Ok(issues) -> {
      // Empty issues list means no problems
      should.be_true(issues == [])
    }
    Error(_) -> should.fail()
  }

  // 4. Serialize configurations
  let node_json = node_config.to_json(initial_node)
  let cluster_json = cluster_config.to_json(initial_cluster)

  should.be_true(node_json != "")
  should.be_true(cluster_json != "")

  // 5. Load from serialized form
  case node_config.from_json_string(node_json) {
    Ok(loaded_node) -> {
      case cluster_config.from_json_string(cluster_json) {
        Ok(loaded_cluster) -> {
          // 6. Validate loaded configurations
          case node_config.validate_config(loaded_node) {
            Ok(Nil) -> Nil
            Error(_) -> should.fail()
          }

          case cluster_config.validate_config(loaded_cluster) {
            Ok(Nil) -> Nil
            Error(_) -> should.fail()
          }

          // 7. Final consistency check
          case
            validation.validate_configs_consistency(
              loaded_node,
              loaded_cluster,
              validation_context,
            )
          {
            Ok(issues) -> {
              // Empty issues list means no problems
              should.be_true(issues == [])
            }
            Error(_) -> should.fail()
          }
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}
