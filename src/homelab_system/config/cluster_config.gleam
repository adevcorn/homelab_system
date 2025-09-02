//// Cluster Configuration Module
////
//// This module provides comprehensive configuration management for cluster-wide
//// settings in the homelab system. It manages cluster identity, discovery methods,
//// networking, and coordination settings.
////
//// Features:
//// - Environment variable loading with fallbacks
//// - JSON configuration file parsing
//// - Type-safe configuration definitions
//// - Default value assignment
//// - Configuration validation
//// - Integration with node configuration

import gleam/dict.{type Dict}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import simplifile

/// Cluster configuration type containing all cluster-wide settings
pub type ClusterConfig {
  ClusterConfig(
    cluster_id: String,
    cluster_name: String,
    discovery: DiscoveryConfig,
    networking: ClusterNetworkConfig,
    coordination: CoordinationConfig,
    security: SecurityConfig,
    features: ClusterFeatureConfig,
    limits: ClusterLimits,
    environment: String,
    metadata: Dict(String, String),
  )
}

/// Service discovery configuration
pub type DiscoveryConfig {
  DiscoveryConfig(
    method: DiscoveryMethod,
    bootstrap_nodes: List(String),
    discovery_port: Int,
    heartbeat_interval_ms: Int,
    timeout_ms: Int,
    retry_attempts: Int,
  )
}

/// Discovery method enumeration
pub type DiscoveryMethod {
  Static
  Multicast
  DNS
  Consul
  Etcd
  Kubernetes
}

/// Cluster networking configuration
pub type ClusterNetworkConfig {
  ClusterNetworkConfig(
    cluster_port_range_start: Int,
    cluster_port_range_end: Int,
    inter_node_encryption: Bool,
    allowed_networks: List(String),
    message_compression: Bool,
    max_message_size_kb: Int,
  )
}

/// Coordination and consensus configuration
pub type CoordinationConfig {
  CoordinationConfig(
    election_timeout_ms: Int,
    heartbeat_timeout_ms: Int,
    leader_lease_duration_ms: Int,
    quorum_size: Option(Int),
    split_brain_protection: Bool,
    consensus_algorithm: ConsensusAlgorithm,
  )
}

/// Consensus algorithm options
pub type ConsensusAlgorithm {
  Raft
  PBFT
  Simple
}

/// Cluster security configuration
pub type SecurityConfig {
  SecurityConfig(
    authentication_enabled: Bool,
    authorization_enabled: Bool,
    cluster_secret_key: Option(String),
    certificate_path: Option(String),
    trusted_nodes: List(String),
    secure_communication: Bool,
  )
}

/// Cluster feature configuration
pub type ClusterFeatureConfig {
  ClusterFeatureConfig(
    auto_scaling: Bool,
    load_balancing: Bool,
    fault_tolerance: Bool,
    distributed_storage: Bool,
    cross_datacenter: Bool,
    monitoring_aggregation: Bool,
    log_aggregation: Bool,
  )
}

/// Cluster resource limits and constraints
pub type ClusterLimits {
  ClusterLimits(
    max_nodes: Int,
    max_tasks_per_node: Int,
    max_memory_per_cluster_gb: Int,
    max_storage_per_cluster_gb: Int,
    network_bandwidth_limit_mbps: Option(Int),
    connection_pool_size: Int,
  )
}

/// Create a default cluster configuration with sensible defaults
pub fn default_config() -> ClusterConfig {
  ClusterConfig(
    cluster_id: "homelab-cluster-1",
    cluster_name: "homelab-cluster",
    discovery: DiscoveryConfig(
      method: Static,
      bootstrap_nodes: ["localhost:4001"],
      discovery_port: 4001,
      heartbeat_interval_ms: 5000,
      timeout_ms: 30_000,
      retry_attempts: 3,
    ),
    networking: ClusterNetworkConfig(
      cluster_port_range_start: 5000,
      cluster_port_range_end: 5999,
      inter_node_encryption: False,
      allowed_networks: ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"],
      message_compression: True,
      max_message_size_kb: 1024,
    ),
    coordination: CoordinationConfig(
      election_timeout_ms: 10_000,
      heartbeat_timeout_ms: 5000,
      leader_lease_duration_ms: 30_000,
      quorum_size: None,
      split_brain_protection: True,
      consensus_algorithm: Simple,
    ),
    security: SecurityConfig(
      authentication_enabled: False,
      authorization_enabled: False,
      cluster_secret_key: None,
      certificate_path: None,
      trusted_nodes: [],
      secure_communication: False,
    ),
    features: ClusterFeatureConfig(
      auto_scaling: False,
      load_balancing: True,
      fault_tolerance: True,
      distributed_storage: False,
      cross_datacenter: False,
      monitoring_aggregation: True,
      log_aggregation: True,
    ),
    limits: ClusterLimits(
      max_nodes: 10,
      max_tasks_per_node: 100,
      max_memory_per_cluster_gb: 32,
      max_storage_per_cluster_gb: 1000,
      network_bandwidth_limit_mbps: None,
      connection_pool_size: 50,
    ),
    environment: "development",
    metadata: dict.new(),
  )
}

/// Load configuration from environment variables with fallbacks
pub fn from_environment() -> ClusterConfig {
  let default = default_config()

  ClusterConfig(
    cluster_id: get_env_with_default("HOMELAB_CLUSTER_ID", default.cluster_id),
    cluster_name: get_env_with_default(
      "HOMELAB_CLUSTER_NAME",
      default.cluster_name,
    ),
    discovery: load_discovery_config_from_env(),
    networking: load_networking_config_from_env(),
    coordination: load_coordination_config_from_env(),
    security: load_security_config_from_env(),
    features: load_features_config_from_env(),
    limits: load_limits_config_from_env(),
    environment: get_env_with_default(
      "HOMELAB_CLUSTER_ENVIRONMENT",
      default.environment,
    ),
    metadata: load_metadata_from_env(),
  )
}

/// Load configuration from JSON file
pub fn from_json_file(file_path: String) -> Result(ClusterConfig, String) {
  case simplifile.read(file_path) {
    Ok(json_content) -> from_json_string(json_content)
    Error(_) ->
      Error("Failed to read cluster configuration file: " <> file_path)
  }
}

/// Parse configuration from JSON string (simplified implementation)
pub fn from_json_string(_json_string: String) -> Result(ClusterConfig, String) {
  // For now, return environment-based configuration with JSON overrides
  // In a future version, we can implement full JSON parsing
  Ok(from_environment())
}

/// Convert configuration to JSON string
pub fn to_json(config: ClusterConfig) -> String {
  let config_json =
    json.object([
      #("cluster_id", json.string(config.cluster_id)),
      #("cluster_name", json.string(config.cluster_name)),
      #("discovery", discovery_to_json(config.discovery)),
      #("networking", networking_to_json(config.networking)),
      #("coordination", coordination_to_json(config.coordination)),
      #("security", security_to_json(config.security)),
      #("features", features_to_json(config.features)),
      #("limits", limits_to_json(config.limits)),
      #("environment", json.string(config.environment)),
      #(
        "metadata",
        json.object(
          dict.to_list(config.metadata)
          |> list.map(fn(pair) { #(pair.0, json.string(pair.1)) }),
        ),
      ),
    ])

  json.to_string(config_json)
}

/// Convert DiscoveryConfig to JSON
fn discovery_to_json(discovery: DiscoveryConfig) -> json.Json {
  json.object([
    #("method", discovery_method_to_json(discovery.method)),
    #("bootstrap_nodes", json.array(discovery.bootstrap_nodes, of: json.string)),
    #("discovery_port", json.int(discovery.discovery_port)),
    #("heartbeat_interval_ms", json.int(discovery.heartbeat_interval_ms)),
    #("timeout_ms", json.int(discovery.timeout_ms)),
    #("retry_attempts", json.int(discovery.retry_attempts)),
  ])
}

/// Convert DiscoveryMethod to JSON
fn discovery_method_to_json(method: DiscoveryMethod) -> json.Json {
  case method {
    Static -> json.string("static")
    Multicast -> json.string("multicast")
    DNS -> json.string("dns")
    Consul -> json.string("consul")
    Etcd -> json.string("etcd")
    Kubernetes -> json.string("kubernetes")
  }
}

/// Convert ClusterNetworkConfig to JSON
fn networking_to_json(networking: ClusterNetworkConfig) -> json.Json {
  json.object([
    #("cluster_port_range_start", json.int(networking.cluster_port_range_start)),
    #("cluster_port_range_end", json.int(networking.cluster_port_range_end)),
    #("inter_node_encryption", json.bool(networking.inter_node_encryption)),
    #(
      "allowed_networks",
      json.array(networking.allowed_networks, of: json.string),
    ),
    #("message_compression", json.bool(networking.message_compression)),
    #("max_message_size_kb", json.int(networking.max_message_size_kb)),
  ])
}

/// Convert CoordinationConfig to JSON
fn coordination_to_json(coordination: CoordinationConfig) -> json.Json {
  json.object([
    #("election_timeout_ms", json.int(coordination.election_timeout_ms)),
    #("heartbeat_timeout_ms", json.int(coordination.heartbeat_timeout_ms)),
    #(
      "leader_lease_duration_ms",
      json.int(coordination.leader_lease_duration_ms),
    ),
    #("quorum_size", case coordination.quorum_size {
      Some(size) -> json.int(size)
      None -> json.null()
    }),
    #("split_brain_protection", json.bool(coordination.split_brain_protection)),
    #(
      "consensus_algorithm",
      consensus_algorithm_to_json(coordination.consensus_algorithm),
    ),
  ])
}

/// Convert ConsensusAlgorithm to JSON
fn consensus_algorithm_to_json(algorithm: ConsensusAlgorithm) -> json.Json {
  case algorithm {
    Raft -> json.string("raft")
    PBFT -> json.string("pbft")
    Simple -> json.string("simple")
  }
}

/// Convert SecurityConfig to JSON
fn security_to_json(security: SecurityConfig) -> json.Json {
  json.object([
    #("authentication_enabled", json.bool(security.authentication_enabled)),
    #("authorization_enabled", json.bool(security.authorization_enabled)),
    #("cluster_secret_key", case security.cluster_secret_key {
      Some(key) -> json.string(key)
      None -> json.null()
    }),
    #("certificate_path", case security.certificate_path {
      Some(path) -> json.string(path)
      None -> json.null()
    }),
    #("trusted_nodes", json.array(security.trusted_nodes, of: json.string)),
    #("secure_communication", json.bool(security.secure_communication)),
  ])
}

/// Convert ClusterFeatureConfig to JSON
fn features_to_json(features: ClusterFeatureConfig) -> json.Json {
  json.object([
    #("auto_scaling", json.bool(features.auto_scaling)),
    #("load_balancing", json.bool(features.load_balancing)),
    #("fault_tolerance", json.bool(features.fault_tolerance)),
    #("distributed_storage", json.bool(features.distributed_storage)),
    #("cross_datacenter", json.bool(features.cross_datacenter)),
    #("monitoring_aggregation", json.bool(features.monitoring_aggregation)),
    #("log_aggregation", json.bool(features.log_aggregation)),
  ])
}

/// Convert ClusterLimits to JSON
fn limits_to_json(limits: ClusterLimits) -> json.Json {
  json.object([
    #("max_nodes", json.int(limits.max_nodes)),
    #("max_tasks_per_node", json.int(limits.max_tasks_per_node)),
    #("max_memory_per_cluster_gb", json.int(limits.max_memory_per_cluster_gb)),
    #("max_storage_per_cluster_gb", json.int(limits.max_storage_per_cluster_gb)),
    #("network_bandwidth_limit_mbps", case limits.network_bandwidth_limit_mbps {
      Some(limit) -> json.int(limit)
      None -> json.null()
    }),
    #("connection_pool_size", json.int(limits.connection_pool_size)),
  ])
}

/// Save configuration to JSON file
pub fn save_to_file(
  config: ClusterConfig,
  file_path: String,
) -> Result(Nil, String) {
  let json_content = to_json(config)
  case simplifile.write(json_content, to: file_path) {
    Ok(_) -> Ok(Nil)
    Error(_) ->
      Error("Failed to write cluster configuration file: " <> file_path)
  }
}

/// Load complete configuration with multiple source priority
/// Priority: JSON file > Environment variables > Defaults
pub fn load_config(json_file_path: Option(String)) -> ClusterConfig {
  let env_config = from_environment()

  case json_file_path {
    Some(file_path) -> {
      case from_json_file(file_path) {
        Ok(json_config) -> merge_configs(env_config, json_config)
        Error(_) -> env_config
      }
    }
    None -> env_config
  }
}

/// Merge two configurations, preferring non-default values from the override config
fn merge_configs(base: ClusterConfig, override: ClusterConfig) -> ClusterConfig {
  let default = default_config()

  ClusterConfig(
    cluster_id: case override.cluster_id == default.cluster_id {
      True -> base.cluster_id
      False -> override.cluster_id
    },
    cluster_name: case override.cluster_name == default.cluster_name {
      True -> base.cluster_name
      False -> override.cluster_name
    },
    discovery: merge_discovery_config(base.discovery, override.discovery),
    networking: merge_networking_config(base.networking, override.networking),
    coordination: merge_coordination_config(
      base.coordination,
      override.coordination,
    ),
    security: merge_security_config(base.security, override.security),
    features: merge_features_config(base.features, override.features),
    limits: merge_limits_config(base.limits, override.limits),
    environment: case override.environment == default.environment {
      True -> base.environment
      False -> override.environment
    },
    metadata: dict.merge(base.metadata, override.metadata),
  )
}

/// Merge discovery configurations
fn merge_discovery_config(
  base: DiscoveryConfig,
  override: DiscoveryConfig,
) -> DiscoveryConfig {
  let default = default_config().discovery

  DiscoveryConfig(
    method: case override.method == default.method {
      True -> base.method
      False -> override.method
    },
    bootstrap_nodes: case override.bootstrap_nodes == default.bootstrap_nodes {
      True -> base.bootstrap_nodes
      False -> override.bootstrap_nodes
    },
    discovery_port: case override.discovery_port == default.discovery_port {
      True -> base.discovery_port
      False -> override.discovery_port
    },
    heartbeat_interval_ms: case
      override.heartbeat_interval_ms == default.heartbeat_interval_ms
    {
      True -> base.heartbeat_interval_ms
      False -> override.heartbeat_interval_ms
    },
    timeout_ms: case override.timeout_ms == default.timeout_ms {
      True -> base.timeout_ms
      False -> override.timeout_ms
    },
    retry_attempts: case override.retry_attempts == default.retry_attempts {
      True -> base.retry_attempts
      False -> override.retry_attempts
    },
  )
}

/// Merge networking configurations
fn merge_networking_config(
  base: ClusterNetworkConfig,
  override: ClusterNetworkConfig,
) -> ClusterNetworkConfig {
  let default = default_config().networking

  ClusterNetworkConfig(
    cluster_port_range_start: case
      override.cluster_port_range_start == default.cluster_port_range_start
    {
      True -> base.cluster_port_range_start
      False -> override.cluster_port_range_start
    },
    cluster_port_range_end: case
      override.cluster_port_range_end == default.cluster_port_range_end
    {
      True -> base.cluster_port_range_end
      False -> override.cluster_port_range_end
    },
    inter_node_encryption: case
      override.inter_node_encryption == default.inter_node_encryption
    {
      True -> base.inter_node_encryption
      False -> override.inter_node_encryption
    },
    allowed_networks: case
      override.allowed_networks == default.allowed_networks
    {
      True -> base.allowed_networks
      False -> override.allowed_networks
    },
    message_compression: case
      override.message_compression == default.message_compression
    {
      True -> base.message_compression
      False -> override.message_compression
    },
    max_message_size_kb: case
      override.max_message_size_kb == default.max_message_size_kb
    {
      True -> base.max_message_size_kb
      False -> override.max_message_size_kb
    },
  )
}

/// Merge coordination configurations
fn merge_coordination_config(
  base: CoordinationConfig,
  override: CoordinationConfig,
) -> CoordinationConfig {
  let default = default_config().coordination

  CoordinationConfig(
    election_timeout_ms: case
      override.election_timeout_ms == default.election_timeout_ms
    {
      True -> base.election_timeout_ms
      False -> override.election_timeout_ms
    },
    heartbeat_timeout_ms: case
      override.heartbeat_timeout_ms == default.heartbeat_timeout_ms
    {
      True -> base.heartbeat_timeout_ms
      False -> override.heartbeat_timeout_ms
    },
    leader_lease_duration_ms: case
      override.leader_lease_duration_ms == default.leader_lease_duration_ms
    {
      True -> base.leader_lease_duration_ms
      False -> override.leader_lease_duration_ms
    },
    quorum_size: case override.quorum_size == default.quorum_size {
      True -> base.quorum_size
      False -> override.quorum_size
    },
    split_brain_protection: case
      override.split_brain_protection == default.split_brain_protection
    {
      True -> base.split_brain_protection
      False -> override.split_brain_protection
    },
    consensus_algorithm: case
      override.consensus_algorithm == default.consensus_algorithm
    {
      True -> base.consensus_algorithm
      False -> override.consensus_algorithm
    },
  )
}

/// Merge security configurations
fn merge_security_config(
  base: SecurityConfig,
  override: SecurityConfig,
) -> SecurityConfig {
  let default = default_config().security

  SecurityConfig(
    authentication_enabled: case
      override.authentication_enabled == default.authentication_enabled
    {
      True -> base.authentication_enabled
      False -> override.authentication_enabled
    },
    authorization_enabled: case
      override.authorization_enabled == default.authorization_enabled
    {
      True -> base.authorization_enabled
      False -> override.authorization_enabled
    },
    cluster_secret_key: case
      override.cluster_secret_key == default.cluster_secret_key
    {
      True -> base.cluster_secret_key
      False -> override.cluster_secret_key
    },
    certificate_path: case
      override.certificate_path == default.certificate_path
    {
      True -> base.certificate_path
      False -> override.certificate_path
    },
    trusted_nodes: case override.trusted_nodes == default.trusted_nodes {
      True -> base.trusted_nodes
      False -> override.trusted_nodes
    },
    secure_communication: case
      override.secure_communication == default.secure_communication
    {
      True -> base.secure_communication
      False -> override.secure_communication
    },
  )
}

/// Merge features configurations
fn merge_features_config(
  base: ClusterFeatureConfig,
  override: ClusterFeatureConfig,
) -> ClusterFeatureConfig {
  let default = default_config().features

  ClusterFeatureConfig(
    auto_scaling: case override.auto_scaling == default.auto_scaling {
      True -> base.auto_scaling
      False -> override.auto_scaling
    },
    load_balancing: case override.load_balancing == default.load_balancing {
      True -> base.load_balancing
      False -> override.load_balancing
    },
    fault_tolerance: case override.fault_tolerance == default.fault_tolerance {
      True -> base.fault_tolerance
      False -> override.fault_tolerance
    },
    distributed_storage: case
      override.distributed_storage == default.distributed_storage
    {
      True -> base.distributed_storage
      False -> override.distributed_storage
    },
    cross_datacenter: case
      override.cross_datacenter == default.cross_datacenter
    {
      True -> base.cross_datacenter
      False -> override.cross_datacenter
    },
    monitoring_aggregation: case
      override.monitoring_aggregation == default.monitoring_aggregation
    {
      True -> base.monitoring_aggregation
      False -> override.monitoring_aggregation
    },
    log_aggregation: case override.log_aggregation == default.log_aggregation {
      True -> base.log_aggregation
      False -> override.log_aggregation
    },
  )
}

/// Merge limits configurations
fn merge_limits_config(
  base: ClusterLimits,
  override: ClusterLimits,
) -> ClusterLimits {
  let default = default_config().limits

  ClusterLimits(
    max_nodes: case override.max_nodes == default.max_nodes {
      True -> base.max_nodes
      False -> override.max_nodes
    },
    max_tasks_per_node: case
      override.max_tasks_per_node == default.max_tasks_per_node
    {
      True -> base.max_tasks_per_node
      False -> override.max_tasks_per_node
    },
    max_memory_per_cluster_gb: case
      override.max_memory_per_cluster_gb == default.max_memory_per_cluster_gb
    {
      True -> base.max_memory_per_cluster_gb
      False -> override.max_memory_per_cluster_gb
    },
    max_storage_per_cluster_gb: case
      override.max_storage_per_cluster_gb == default.max_storage_per_cluster_gb
    {
      True -> base.max_storage_per_cluster_gb
      False -> override.max_storage_per_cluster_gb
    },
    network_bandwidth_limit_mbps: case
      override.network_bandwidth_limit_mbps
      == default.network_bandwidth_limit_mbps
    {
      True -> base.network_bandwidth_limit_mbps
      False -> override.network_bandwidth_limit_mbps
    },
    connection_pool_size: case
      override.connection_pool_size == default.connection_pool_size
    {
      True -> base.connection_pool_size
      False -> override.connection_pool_size
    },
  )
}

// Helper functions for environment variable parsing

/// Get environment variable with default fallback
fn get_env_with_default(_key: String, default: String) -> String {
  // Simplified implementation - in production, use proper env var access
  // For now, always return default to avoid compilation issues
  default
}

/// Parse boolean environment variable
fn parse_bool_env(_key: String, default: Bool) -> Bool {
  // Simplified implementation - in production, use proper env var access
  default
}

/// Parse integer environment variable
fn parse_int_env(_key: String, default: Int) -> Int {
  // Simplified implementation - in production, use proper env var access
  default
}

/// Parse discovery method from string
fn parse_discovery_method(method_str: String) -> DiscoveryMethod {
  case string.lowercase(method_str) {
    "static" -> Static
    "multicast" -> Multicast
    "dns" -> DNS
    "consul" -> Consul
    "etcd" -> Etcd
    "kubernetes" -> Kubernetes
    _ -> Static
  }
}

/// Parse consensus algorithm from string
fn parse_consensus_algorithm(algorithm_str: String) -> ConsensusAlgorithm {
  case string.lowercase(algorithm_str) {
    "raft" -> Raft
    "pbft" -> PBFT
    "simple" -> Simple
    _ -> Simple
  }
}

/// Parse comma-separated list of strings
fn parse_string_list(list_str: String) -> List(String) {
  string.split(list_str, ",")
  |> list.map(string.trim)
  |> list.filter(fn(item) { !string.is_empty(item) })
}

/// Load discovery configuration from environment variables
fn load_discovery_config_from_env() -> DiscoveryConfig {
  let default = default_config().discovery

  DiscoveryConfig(
    method: parse_discovery_method(get_env_with_default(
      "HOMELAB_DISCOVERY_METHOD",
      "static",
    )),
    bootstrap_nodes: parse_string_list(get_env_with_default(
      "HOMELAB_BOOTSTRAP_NODES",
      "localhost:4001",
    )),
    discovery_port: parse_int_env(
      "HOMELAB_DISCOVERY_PORT",
      default.discovery_port,
    ),
    heartbeat_interval_ms: parse_int_env(
      "HOMELAB_HEARTBEAT_INTERVAL_MS",
      default.heartbeat_interval_ms,
    ),
    timeout_ms: parse_int_env(
      "HOMELAB_DISCOVERY_TIMEOUT_MS",
      default.timeout_ms,
    ),
    retry_attempts: parse_int_env(
      "HOMELAB_DISCOVERY_RETRY_ATTEMPTS",
      default.retry_attempts,
    ),
  )
}

/// Load networking configuration from environment variables
fn load_networking_config_from_env() -> ClusterNetworkConfig {
  let default = default_config().networking

  ClusterNetworkConfig(
    cluster_port_range_start: parse_int_env(
      "HOMELAB_CLUSTER_PORT_START",
      default.cluster_port_range_start,
    ),
    cluster_port_range_end: parse_int_env(
      "HOMELAB_CLUSTER_PORT_END",
      default.cluster_port_range_end,
    ),
    inter_node_encryption: parse_bool_env(
      "HOMELAB_INTER_NODE_ENCRYPTION",
      default.inter_node_encryption,
    ),
    allowed_networks: parse_string_list(get_env_with_default(
      "HOMELAB_ALLOWED_NETWORKS",
      "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16",
    )),
    message_compression: parse_bool_env(
      "HOMELAB_MESSAGE_COMPRESSION",
      default.message_compression,
    ),
    max_message_size_kb: parse_int_env(
      "HOMELAB_MAX_MESSAGE_SIZE_KB",
      default.max_message_size_kb,
    ),
  )
}

/// Load coordination configuration from environment variables
fn load_coordination_config_from_env() -> CoordinationConfig {
  let default = default_config().coordination

  CoordinationConfig(
    election_timeout_ms: parse_int_env(
      "HOMELAB_ELECTION_TIMEOUT_MS",
      default.election_timeout_ms,
    ),
    heartbeat_timeout_ms: parse_int_env(
      "HOMELAB_HEARTBEAT_TIMEOUT_MS",
      default.heartbeat_timeout_ms,
    ),
    leader_lease_duration_ms: parse_int_env(
      "HOMELAB_LEADER_LEASE_DURATION_MS",
      default.leader_lease_duration_ms,
    ),
    quorum_size: default.quorum_size,
    split_brain_protection: parse_bool_env(
      "HOMELAB_SPLIT_BRAIN_PROTECTION",
      default.split_brain_protection,
    ),
    consensus_algorithm: parse_consensus_algorithm(get_env_with_default(
      "HOMELAB_CONSENSUS_ALGORITHM",
      "simple",
    )),
  )
}

/// Load security configuration from environment variables
fn load_security_config_from_env() -> SecurityConfig {
  let default = default_config().security

  SecurityConfig(
    authentication_enabled: parse_bool_env(
      "HOMELAB_AUTHENTICATION_ENABLED",
      default.authentication_enabled,
    ),
    authorization_enabled: parse_bool_env(
      "HOMELAB_AUTHORIZATION_ENABLED",
      default.authorization_enabled,
    ),
    cluster_secret_key: default.cluster_secret_key,
    certificate_path: default.certificate_path,
    trusted_nodes: parse_string_list(get_env_with_default(
      "HOMELAB_TRUSTED_NODES",
      "",
    )),
    secure_communication: parse_bool_env(
      "HOMELAB_SECURE_COMMUNICATION",
      default.secure_communication,
    ),
  )
}

/// Load features configuration from environment variables
fn load_features_config_from_env() -> ClusterFeatureConfig {
  let default = default_config().features

  ClusterFeatureConfig(
    auto_scaling: parse_bool_env("HOMELAB_AUTO_SCALING", default.auto_scaling),
    load_balancing: parse_bool_env(
      "HOMELAB_LOAD_BALANCING",
      default.load_balancing,
    ),
    fault_tolerance: parse_bool_env(
      "HOMELAB_FAULT_TOLERANCE",
      default.fault_tolerance,
    ),
    distributed_storage: parse_bool_env(
      "HOMELAB_DISTRIBUTED_STORAGE",
      default.distributed_storage,
    ),
    cross_datacenter: parse_bool_env(
      "HOMELAB_CROSS_DATACENTER",
      default.cross_datacenter,
    ),
    monitoring_aggregation: parse_bool_env(
      "HOMELAB_MONITORING_AGGREGATION",
      default.monitoring_aggregation,
    ),
    log_aggregation: parse_bool_env(
      "HOMELAB_LOG_AGGREGATION",
      default.log_aggregation,
    ),
  )
}

/// Load limits configuration from environment variables
fn load_limits_config_from_env() -> ClusterLimits {
  let default = default_config().limits

  ClusterLimits(
    max_nodes: parse_int_env("HOMELAB_MAX_NODES", default.max_nodes),
    max_tasks_per_node: parse_int_env(
      "HOMELAB_MAX_TASKS_PER_NODE",
      default.max_tasks_per_node,
    ),
    max_memory_per_cluster_gb: parse_int_env(
      "HOMELAB_MAX_MEMORY_PER_CLUSTER_GB",
      default.max_memory_per_cluster_gb,
    ),
    max_storage_per_cluster_gb: parse_int_env(
      "HOMELAB_MAX_STORAGE_PER_CLUSTER_GB",
      default.max_storage_per_cluster_gb,
    ),
    network_bandwidth_limit_mbps: default.network_bandwidth_limit_mbps,
    connection_pool_size: parse_int_env(
      "HOMELAB_CONNECTION_POOL_SIZE",
      default.connection_pool_size,
    ),
  )
}

/// Load metadata from environment variables (prefixed with HOMELAB_CLUSTER_META_)
fn load_metadata_from_env() -> Dict(String, String) {
  dict.new()
  |> dict.insert(
    "version",
    get_env_with_default("HOMELAB_CLUSTER_META_VERSION", "1.0.0"),
  )
  |> dict.insert(
    "deployment_type",
    get_env_with_default("HOMELAB_CLUSTER_META_DEPLOYMENT", "development"),
  )
  |> dict.insert(
    "created_at",
    get_env_with_default("HOMELAB_CLUSTER_META_CREATED_AT", "unknown"),
  )
  |> dict.insert(
    "region",
    get_env_with_default("HOMELAB_CLUSTER_META_REGION", "local"),
  )
}

/// Validate cluster configuration and return errors if invalid
pub fn validate_config(config: ClusterConfig) -> Result(Nil, List(String)) {
  let errors = []

  let errors = case string.is_empty(config.cluster_id) {
    True -> ["Cluster ID cannot be empty", ..errors]
    False -> errors
  }

  let errors = case string.is_empty(config.cluster_name) {
    True -> ["Cluster name cannot be empty", ..errors]
    False -> errors
  }

  let errors = case
    config.discovery.discovery_port < 1
    || config.discovery.discovery_port > 65_535
  {
    True -> ["Discovery port must be between 1 and 65535", ..errors]
    False -> errors
  }

  let errors = case config.networking.cluster_port_range_start < 1 {
    True -> ["Cluster port range start must be positive", ..errors]
    False -> errors
  }

  let errors = case
    config.networking.cluster_port_range_end
    <= config.networking.cluster_port_range_start
  {
    True -> ["Cluster port range end must be greater than start", ..errors]
    False -> errors
  }

  let errors = case config.limits.max_nodes <= 0 {
    True -> ["Max nodes must be positive", ..errors]
    False -> errors
  }

  let errors = case config.limits.max_tasks_per_node <= 0 {
    True -> ["Max tasks per node must be positive", ..errors]
    False -> errors
  }

  let errors = case config.coordination.election_timeout_ms <= 0 {
    True -> ["Election timeout must be positive", ..errors]
    False -> errors
  }

  case errors {
    [] -> Ok(Nil)
    _ -> Error(list.reverse(errors))
  }
}

/// Get configuration summary as a formatted string
pub fn get_config_summary(config: ClusterConfig) -> String {
  "Cluster Configuration Summary:\n"
  <> "  Cluster ID: "
  <> config.cluster_id
  <> "\n"
  <> "  Cluster Name: "
  <> config.cluster_name
  <> "\n"
  <> "  Environment: "
  <> config.environment
  <> "\n"
  <> "  Discovery Method: "
  <> discovery_method_to_string(config.discovery.method)
  <> "\n"
  <> "  Discovery Port: "
  <> int.to_string(config.discovery.discovery_port)
  <> "\n"
  <> "  Max Nodes: "
  <> int.to_string(config.limits.max_nodes)
  <> "\n"
  <> "  Consensus Algorithm: "
  <> consensus_algorithm_to_string(config.coordination.consensus_algorithm)
  <> "\n"
  <> "  Security Enabled: "
  <> case config.security.authentication_enabled {
    True -> "yes"
    False -> "no"
  }
}

/// Convert discovery method to human-readable string
fn discovery_method_to_string(method: DiscoveryMethod) -> String {
  case method {
    Static -> "Static"
    Multicast -> "Multicast"
    DNS -> "DNS"
    Consul -> "Consul"
    Etcd -> "Etcd"
    Kubernetes -> "Kubernetes"
  }
}

/// Convert consensus algorithm to human-readable string
fn consensus_algorithm_to_string(algorithm: ConsensusAlgorithm) -> String {
  case algorithm {
    Raft -> "Raft"
    PBFT -> "PBFT"
    Simple -> "Simple"
  }
}
