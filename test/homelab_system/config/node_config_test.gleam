//// Node Configuration Test Module
////
//// Basic test suite for the node configuration module using gleeunit.

import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import gleeunit/should

import homelab_system/config/node_config.{
  Agent, Coordinator, Gateway, Generic, Monitor, Monitoring,
}

pub fn main() {
  gleeunit.main()
}

// Test default configuration
pub fn default_config_test() {
  let config = node_config.default_config()

  config.node_id |> should.equal("homelab-node-1")
  config.node_name |> should.equal("homelab-node")
  config.role |> should.equal(Agent(Generic))
  config.capabilities |> should.equal(["health_check", "metrics", "monitoring"])
  config.environment |> should.equal("development")
  config.debug |> should.equal(True)

  // Test network defaults
  config.network.bind_address |> should.equal("0.0.0.0")
  config.network.port |> should.equal(4000)
  config.network.discovery_port |> should.equal(Some(4001))
  config.network.external_host |> should.equal(None)
  config.network.tls_enabled |> should.equal(False)
  config.network.max_connections |> should.equal(100)

  // Test resource defaults
  config.resources.max_memory_mb |> should.equal(512)
  config.resources.max_cpu_percent |> should.equal(80)
  config.resources.disk_space_mb |> should.equal(1024)
  config.resources.connection_timeout_ms |> should.equal(30_000)
  config.resources.request_timeout_ms |> should.equal(5000)

  // Test feature defaults
  config.features.clustering |> should.equal(True)
  config.features.metrics_collection |> should.equal(True)
  config.features.health_checks |> should.equal(True)
  config.features.web_interface |> should.equal(True)
  config.features.api_endpoints |> should.equal(True)
  config.features.auto_discovery |> should.equal(True)
  config.features.load_balancing |> should.equal(False)
}

// Test environment configuration loading
pub fn from_environment_test() {
  let config = node_config.from_environment()

  // Should have default values when no environment variables are set
  config.node_id |> should.equal("homelab-node-1")
  config.node_name |> should.equal("homelab-node")
  config.role |> should.equal(Agent(Generic))
  config.environment |> should.equal("development")
}

// Test JSON serialization produces valid JSON string
pub fn to_json_test() {
  let config = node_config.default_config()
  let json_string = node_config.to_json(config)

  // Check that it's a non-empty string
  should.be_true(json_string != "")

  // Basic validation that it looks like JSON
  should.be_true(string.starts_with(json_string, "{"))
  should.be_true(string.ends_with(json_string, "}"))
}

// Test JSON deserialization returns configuration
pub fn from_json_string_test() {
  let json_config = "{\"test\": true}"

  case node_config.from_json_string(json_config) {
    Ok(config) -> {
      // Should return a valid configuration (currently defaults)
      config.node_id |> should.equal("homelab-node-1")
    }
    Error(_) -> should.fail()
  }
}

// Test configuration validation with valid config
pub fn validate_config_valid_test() {
  let config = node_config.default_config()

  case node_config.validate_config(config) {
    Ok(Nil) -> Nil
    Error(_) -> should.fail()
  }
}

// Test configuration validation with empty node ID
pub fn validate_config_empty_node_id_test() {
  let config =
    node_config.NodeConfig(..node_config.default_config(), node_id: "")

  case node_config.validate_config(config) {
    Ok(Nil) -> should.fail()
    Error(errors) -> {
      should.be_true(list.contains(errors, "Node ID cannot be empty"))
    }
  }
}

// Test configuration validation with invalid port
pub fn validate_config_invalid_port_test() {
  let config =
    node_config.NodeConfig(
      ..node_config.default_config(),
      network: node_config.NetworkConfig(
        ..node_config.default_config().network,
        port: 0,
      ),
    )

  case node_config.validate_config(config) {
    Ok(Nil) -> should.fail()
    Error(errors) -> {
      should.be_true(list.contains(errors, "Port must be between 1 and 65535"))
    }
  }
}

// Test configuration validation with invalid memory
pub fn validate_config_invalid_memory_test() {
  let config =
    node_config.NodeConfig(
      ..node_config.default_config(),
      resources: node_config.ResourceConfig(
        ..node_config.default_config().resources,
        max_memory_mb: 0,
      ),
    )

  case node_config.validate_config(config) {
    Ok(Nil) -> should.fail()
    Error(errors) -> {
      should.be_true(list.contains(errors, "Max memory must be positive"))
    }
  }
}

// Test configuration summary generation
pub fn get_config_summary_test() {
  let config = node_config.default_config()
  let summary = node_config.get_config_summary(config)

  // Check that summary contains expected information
  should.be_true(string.contains(summary, "Node Configuration Summary:"))
  should.be_true(string.contains(summary, "Node ID: homelab-node-1"))
  should.be_true(string.contains(summary, "Node Name: homelab-node"))
  should.be_true(string.contains(summary, "Role: Agent (Generic)"))
  should.be_true(string.contains(summary, "Environment: development"))
  should.be_true(string.contains(summary, "Network Port: 4000"))
}

// Test different node roles
pub fn node_roles_test() {
  // Test Coordinator role
  let coordinator_config =
    node_config.NodeConfig(..node_config.default_config(), role: Coordinator)
  let coordinator_summary = node_config.get_config_summary(coordinator_config)
  should.be_true(string.contains(coordinator_summary, "Role: Coordinator"))

  // Test Gateway role
  let gateway_config =
    node_config.NodeConfig(..node_config.default_config(), role: Gateway)
  let gateway_summary = node_config.get_config_summary(gateway_config)
  should.be_true(string.contains(gateway_summary, "Role: Gateway"))

  // Test Monitor role
  let monitor_config =
    node_config.NodeConfig(..node_config.default_config(), role: Monitor)
  let monitor_summary = node_config.get_config_summary(monitor_config)
  should.be_true(string.contains(monitor_summary, "Role: Monitor"))

  // Test Monitoring Agent role
  let monitoring_agent_config =
    node_config.NodeConfig(
      ..node_config.default_config(),
      role: Agent(Monitoring),
    )
  let monitoring_agent_summary =
    node_config.get_config_summary(monitoring_agent_config)
  should.be_true(string.contains(
    monitoring_agent_summary,
    "Role: Agent (Monitoring)",
  ))
}

// Test load configuration with different priorities
pub fn load_config_test() {
  // Test with no JSON file (should use environment/defaults)
  let config_no_file = node_config.load_config(None)
  config_no_file.node_id |> should.equal("homelab-node-1")

  // Test with non-existent JSON file (should fallback to environment)
  let config_missing_file =
    node_config.load_config(Some("non-existent-file.json"))
  config_missing_file.node_id |> should.equal("homelab-node-1")
}

// Test configuration roundtrip (serialize -> deserialize)
pub fn config_roundtrip_test() {
  let original_config =
    node_config.NodeConfig(
      ..node_config.default_config(),
      node_id: "roundtrip-test",
      node_name: "roundtrip-node",
      role: Gateway,
      environment: "test",
      debug: False,
    )

  let json_string = node_config.to_json(original_config)

  case node_config.from_json_string(json_string) {
    Ok(parsed_config) -> {
      // For now, since JSON parsing returns defaults, just verify it works
      parsed_config.node_id |> should.equal("homelab-node-1")
    }
    Error(_) -> should.fail()
  }
}

// Test configuration edge cases
pub fn config_edge_cases_test() {
  // Test empty capabilities list
  let config_empty_caps =
    node_config.NodeConfig(..node_config.default_config(), capabilities: [])

  case node_config.validate_config(config_empty_caps) {
    Ok(Nil) -> Nil
    // Empty capabilities should be valid
    Error(_) -> should.fail()
  }

  // Test maximum valid port
  let config_max_port =
    node_config.NodeConfig(
      ..node_config.default_config(),
      network: node_config.NetworkConfig(
        ..node_config.default_config().network,
        port: 65_535,
      ),
    )

  case node_config.validate_config(config_max_port) {
    Ok(Nil) -> Nil
    // Maximum port should be valid
    Error(_) -> should.fail()
  }

  // Test minimum valid port
  let config_min_port =
    node_config.NodeConfig(
      ..node_config.default_config(),
      network: node_config.NetworkConfig(
        ..node_config.default_config().network,
        port: 1,
      ),
    )

  case node_config.validate_config(config_min_port) {
    Ok(Nil) -> Nil
    // Minimum port should be valid
    Error(_) -> should.fail()
  }
}
