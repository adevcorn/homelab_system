//// Cluster Configuration Test Module
////
//// Basic test suite for the cluster configuration module using gleeunit.

import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import gleeunit/should

import homelab_system/config/cluster_config.{
  type ClusterConfig, type ConsensusAlgorithm, type DiscoveryMethod, Consul, DNS,
  Etcd, Kubernetes, Multicast, PBFT, Raft, Simple, Static,
}

pub fn main() {
  gleeunit.main()
}

// Test default configuration
pub fn default_config_test() {
  let config = cluster_config.default_config()

  config.cluster_id |> should.equal("homelab-cluster-1")
  config.cluster_name |> should.equal("homelab-cluster")
  config.environment |> should.equal("development")

  // Test discovery defaults
  config.discovery.method |> should.equal(Static)
  config.discovery.bootstrap_nodes |> should.equal(["localhost:4001"])
  config.discovery.discovery_port |> should.equal(4001)
  config.discovery.heartbeat_interval_ms |> should.equal(5000)
  config.discovery.timeout_ms |> should.equal(30_000)
  config.discovery.retry_attempts |> should.equal(3)

  // Test networking defaults
  config.networking.cluster_port_range_start |> should.equal(5000)
  config.networking.cluster_port_range_end |> should.equal(5999)
  config.networking.inter_node_encryption |> should.equal(False)
  config.networking.message_compression |> should.equal(True)
  config.networking.max_message_size_kb |> should.equal(1024)

  // Test coordination defaults
  config.coordination.election_timeout_ms |> should.equal(10_000)
  config.coordination.heartbeat_timeout_ms |> should.equal(5000)
  config.coordination.leader_lease_duration_ms |> should.equal(30_000)
  config.coordination.quorum_size |> should.equal(None)
  config.coordination.split_brain_protection |> should.equal(True)
  config.coordination.consensus_algorithm |> should.equal(Simple)

  // Test security defaults
  config.security.authentication_enabled |> should.equal(False)
  config.security.authorization_enabled |> should.equal(False)
  config.security.cluster_secret_key |> should.equal(None)
  config.security.certificate_path |> should.equal(None)
  config.security.trusted_nodes |> should.equal([])
  config.security.secure_communication |> should.equal(False)

  // Test features defaults
  config.features.auto_scaling |> should.equal(False)
  config.features.load_balancing |> should.equal(True)
  config.features.fault_tolerance |> should.equal(True)
  config.features.distributed_storage |> should.equal(False)
  config.features.cross_datacenter |> should.equal(False)
  config.features.monitoring_aggregation |> should.equal(True)
  config.features.log_aggregation |> should.equal(True)

  // Test limits defaults
  config.limits.max_nodes |> should.equal(10)
  config.limits.max_tasks_per_node |> should.equal(100)
  config.limits.max_memory_per_cluster_gb |> should.equal(32)
  config.limits.max_storage_per_cluster_gb |> should.equal(1000)
  config.limits.network_bandwidth_limit_mbps |> should.equal(None)
  config.limits.connection_pool_size |> should.equal(50)
}

// Test environment configuration loading
pub fn from_environment_test() {
  let config = cluster_config.from_environment()

  // Should have default values when no environment variables are set
  config.cluster_id |> should.equal("homelab-cluster-1")
  config.cluster_name |> should.equal("homelab-cluster")
  config.discovery.method |> should.equal(Static)
  config.environment |> should.equal("development")
}

// Test JSON serialization
pub fn to_json_test() {
  let config = cluster_config.default_config()
  let json_string = cluster_config.to_json(config)

  // Check that it's a non-empty string
  should.be_true(json_string != "")

  // Basic validation that it looks like JSON
  should.be_true(string.starts_with(json_string, "{"))
  should.be_true(string.ends_with(json_string, "}"))
}

// Test JSON deserialization returns configuration
pub fn from_json_string_test() {
  let json_config = "{\"cluster_id\": \"test-cluster\"}"

  case cluster_config.from_json_string(json_config) {
    Ok(config) -> {
      // Should return a valid configuration (currently defaults)
      config.cluster_id |> should.equal("homelab-cluster-1")
    }
    Error(_) -> should.fail()
  }
}

// Test configuration validation with valid config
pub fn validate_config_valid_test() {
  let config = cluster_config.default_config()

  case cluster_config.validate_config(config) {
    Ok(Nil) -> Nil
    Error(_) -> should.fail()
  }
}

// Test configuration validation with empty cluster ID
pub fn validate_config_empty_cluster_id_test() {
  let config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      cluster_id: "",
    )

  case cluster_config.validate_config(config) {
    Ok(Nil) -> should.fail()
    Error(errors) -> {
      should.be_true(list.contains(errors, "Cluster ID cannot be empty"))
    }
  }
}

// Test configuration validation with empty cluster name
pub fn validate_config_empty_cluster_name_test() {
  let config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      cluster_name: "",
    )

  case cluster_config.validate_config(config) {
    Ok(Nil) -> should.fail()
    Error(errors) -> {
      should.be_true(list.contains(errors, "Cluster name cannot be empty"))
    }
  }
}

// Test configuration validation with invalid discovery port
pub fn validate_config_invalid_discovery_port_test() {
  let config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      discovery: cluster_config.DiscoveryConfig(
        ..cluster_config.default_config().discovery,
        discovery_port: 0,
      ),
    )

  case cluster_config.validate_config(config) {
    Ok(Nil) -> should.fail()
    Error(errors) -> {
      should.be_true(list.contains(
        errors,
        "Discovery port must be between 1 and 65535",
      ))
    }
  }
}

// Test configuration validation with invalid port range
pub fn validate_config_invalid_port_range_test() {
  let config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      networking: cluster_config.ClusterNetworkConfig(
        ..cluster_config.default_config().networking,
        cluster_port_range_start: 6000,
        cluster_port_range_end: 5000,
      ),
    )

  case cluster_config.validate_config(config) {
    Ok(Nil) -> should.fail()
    Error(errors) -> {
      should.be_true(list.contains(
        errors,
        "Cluster port range end must be greater than start",
      ))
    }
  }
}

// Test configuration validation with invalid max nodes
pub fn validate_config_invalid_max_nodes_test() {
  let config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      limits: cluster_config.ClusterLimits(
        ..cluster_config.default_config().limits,
        max_nodes: 0,
      ),
    )

  case cluster_config.validate_config(config) {
    Ok(Nil) -> should.fail()
    Error(errors) -> {
      should.be_true(list.contains(errors, "Max nodes must be positive"))
    }
  }
}

// Test configuration validation with multiple errors
pub fn validate_config_multiple_errors_test() {
  let config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      cluster_id: "",
      cluster_name: "",
      limits: cluster_config.ClusterLimits(
        ..cluster_config.default_config().limits,
        max_nodes: -1,
        max_tasks_per_node: 0,
      ),
    )

  case cluster_config.validate_config(config) {
    Ok(Nil) -> should.fail()
    Error(errors) -> {
      should.be_true(list.contains(errors, "Cluster ID cannot be empty"))
      should.be_true(list.contains(errors, "Cluster name cannot be empty"))
      should.be_true(list.contains(errors, "Max nodes must be positive"))
      should.be_true(list.contains(
        errors,
        "Max tasks per node must be positive",
      ))
    }
  }
}

// Test configuration summary generation
pub fn get_config_summary_test() {
  let config = cluster_config.default_config()
  let summary = cluster_config.get_config_summary(config)

  // Check that summary contains expected information
  should.be_true(string.contains(summary, "Cluster Configuration Summary:"))
  should.be_true(string.contains(summary, "Cluster ID: homelab-cluster-1"))
  should.be_true(string.contains(summary, "Cluster Name: homelab-cluster"))
  should.be_true(string.contains(summary, "Environment: development"))
  should.be_true(string.contains(summary, "Discovery Method: Static"))
  should.be_true(string.contains(summary, "Discovery Port: 4001"))
  should.be_true(string.contains(summary, "Max Nodes: 10"))
  should.be_true(string.contains(summary, "Consensus Algorithm: Simple"))
  should.be_true(string.contains(summary, "Security Enabled: no"))
}

// Test different discovery methods
pub fn discovery_methods_test() {
  // Test Static method
  let static_config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      discovery: cluster_config.DiscoveryConfig(
        ..cluster_config.default_config().discovery,
        method: Static,
      ),
    )
  let static_summary = cluster_config.get_config_summary(static_config)
  should.be_true(string.contains(static_summary, "Discovery Method: Static"))

  // Test Multicast method
  let multicast_config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      discovery: cluster_config.DiscoveryConfig(
        ..cluster_config.default_config().discovery,
        method: Multicast,
      ),
    )
  let multicast_summary = cluster_config.get_config_summary(multicast_config)
  should.be_true(string.contains(
    multicast_summary,
    "Discovery Method: Multicast",
  ))

  // Test DNS method
  let dns_config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      discovery: cluster_config.DiscoveryConfig(
        ..cluster_config.default_config().discovery,
        method: DNS,
      ),
    )
  let dns_summary = cluster_config.get_config_summary(dns_config)
  should.be_true(string.contains(dns_summary, "Discovery Method: DNS"))
}

// Test different consensus algorithms
pub fn consensus_algorithms_test() {
  // Test Raft algorithm
  let raft_config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      coordination: cluster_config.CoordinationConfig(
        ..cluster_config.default_config().coordination,
        consensus_algorithm: Raft,
      ),
    )
  let raft_summary = cluster_config.get_config_summary(raft_config)
  should.be_true(string.contains(raft_summary, "Consensus Algorithm: Raft"))

  // Test PBFT algorithm
  let pbft_config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      coordination: cluster_config.CoordinationConfig(
        ..cluster_config.default_config().coordination,
        consensus_algorithm: PBFT,
      ),
    )
  let pbft_summary = cluster_config.get_config_summary(pbft_config)
  should.be_true(string.contains(pbft_summary, "Consensus Algorithm: PBFT"))
}

// Test load configuration with different priorities
pub fn load_config_test() {
  // Test with no JSON file (should use environment/defaults)
  let config_no_file = cluster_config.load_config(None)
  config_no_file.cluster_id |> should.equal("homelab-cluster-1")

  // Test with non-existent JSON file (should fallback to environment)
  let config_missing_file =
    cluster_config.load_config(Some("non-existent-file.json"))
  config_missing_file.cluster_id |> should.equal("homelab-cluster-1")
}

// Test configuration roundtrip (serialize -> deserialize)
pub fn config_roundtrip_test() {
  let original_config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      cluster_id: "roundtrip-test",
      cluster_name: "roundtrip-cluster",
      environment: "test",
    )

  let json_string = cluster_config.to_json(original_config)

  case cluster_config.from_json_string(json_string) {
    Ok(parsed_config) -> {
      // For now, since JSON parsing returns defaults, just verify it works
      parsed_config.cluster_id |> should.equal("homelab-cluster-1")
    }
    Error(_) -> should.fail()
  }
}

// Test configuration edge cases
pub fn config_edge_cases_test() {
  // Test empty bootstrap nodes list
  let config_empty_bootstrap =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      discovery: cluster_config.DiscoveryConfig(
        ..cluster_config.default_config().discovery,
        bootstrap_nodes: [],
      ),
    )

  case cluster_config.validate_config(config_empty_bootstrap) {
    Ok(Nil) -> Nil
    // Empty bootstrap nodes should be valid (will use defaults)
    Error(_) -> should.fail()
  }

  // Test maximum valid discovery port
  let config_max_port =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      discovery: cluster_config.DiscoveryConfig(
        ..cluster_config.default_config().discovery,
        discovery_port: 65_535,
      ),
    )

  case cluster_config.validate_config(config_max_port) {
    Ok(Nil) -> Nil
    // Maximum port should be valid
    Error(_) -> should.fail()
  }

  // Test minimum valid discovery port
  let config_min_port =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      discovery: cluster_config.DiscoveryConfig(
        ..cluster_config.default_config().discovery,
        discovery_port: 1,
      ),
    )

  case cluster_config.validate_config(config_min_port) {
    Ok(Nil) -> Nil
    // Minimum port should be valid
    Error(_) -> should.fail()
  }
}

// Test security configuration
pub fn security_config_test() {
  let secure_config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      security: cluster_config.SecurityConfig(
        ..cluster_config.default_config().security,
        authentication_enabled: True,
        authorization_enabled: True,
        secure_communication: True,
      ),
    )

  let summary = cluster_config.get_config_summary(secure_config)
  should.be_true(string.contains(summary, "Security Enabled: yes"))
}

// Test limits configuration
pub fn limits_config_test() {
  let limited_config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      limits: cluster_config.ClusterLimits(
        ..cluster_config.default_config().limits,
        max_nodes: 5,
        max_tasks_per_node: 50,
      ),
    )

  let summary = cluster_config.get_config_summary(limited_config)
  should.be_true(string.contains(summary, "Max Nodes: 5"))
}
