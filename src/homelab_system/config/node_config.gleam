//// Node Configuration Module
////
//// This module provides comprehensive configuration management for individual nodes
//// in the homelab system. It supports loading configuration from multiple sources
//// with proper fallback mechanisms and type safety.
////
//// Features:
//// - Environment variable loading with fallbacks
//// - JSON configuration file parsing
//// - Type-safe configuration definitions
//// - Default value assignment
//// - Configuration validation

import gleam/dict.{type Dict}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import glenvy/env
import simplifile

/// Node configuration type containing all node-specific settings
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

/// Node role enumeration defining the type of node
pub type NodeRole {
  Coordinator
  Agent(agent_type: AgentType)
  Gateway
  Monitor
}

/// Agent types for specialized node functions
pub type AgentType {
  Monitoring
  Storage
  Compute
  Network
  Generic
}

/// Network configuration for node communication
pub type NetworkConfig {
  NetworkConfig(
    bind_address: String,
    port: Int,
    discovery_port: Option(Int),
    external_host: Option(String),
    tls_enabled: Bool,
    max_connections: Int,
  )
}

/// Resource limits and allocations
pub type ResourceConfig {
  ResourceConfig(
    max_memory_mb: Int,
    max_cpu_percent: Int,
    disk_space_mb: Int,
    connection_timeout_ms: Int,
    request_timeout_ms: Int,
  )
}

/// Feature flags and optional functionality
pub type FeatureConfig {
  FeatureConfig(
    clustering: Bool,
    metrics_collection: Bool,
    health_checks: Bool,
    web_interface: Bool,
    api_endpoints: Bool,
    auto_discovery: Bool,
    load_balancing: Bool,
  )
}

/// Configuration loading result
pub type ConfigResult {
  ConfigSuccess(config: NodeConfig)
  ConfigError(message: String)
}

/// Create a default node configuration with sensible defaults
pub fn default_config() -> NodeConfig {
  NodeConfig(
    node_id: "homelab-node-1",
    node_name: "homelab-node",
    role: Agent(Generic),
    capabilities: ["health_check", "metrics", "monitoring"],
    network: NetworkConfig(
      bind_address: "0.0.0.0",
      port: 4000,
      discovery_port: Some(4001),
      external_host: None,
      tls_enabled: False,
      max_connections: 100,
    ),
    resources: ResourceConfig(
      max_memory_mb: 512,
      max_cpu_percent: 80,
      disk_space_mb: 1024,
      connection_timeout_ms: 30_000,
      request_timeout_ms: 5000,
    ),
    features: FeatureConfig(
      clustering: True,
      metrics_collection: True,
      health_checks: True,
      web_interface: True,
      api_endpoints: True,
      auto_discovery: True,
      load_balancing: False,
    ),
    environment: "development",
    debug: True,
    metadata: dict.new(),
  )
}

/// Load configuration from environment variables with fallbacks
pub fn from_environment() -> NodeConfig {
  let default = default_config()

  NodeConfig(
    node_id: get_env_with_default("HOMELAB_NODE_ID", default.node_id),
    node_name: get_env_with_default("HOMELAB_NODE_NAME", default.node_name),
    role: parse_node_role(get_env_with_default("HOMELAB_NODE_ROLE", "agent")),
    capabilities: parse_capabilities(get_env_with_default(
      "HOMELAB_CAPABILITIES",
      "health_check,metrics",
    )),
    network: load_network_config_from_env(),
    resources: load_resource_config_from_env(),
    features: load_feature_config_from_env(),
    environment: get_env_with_default(
      "HOMELAB_ENVIRONMENT",
      default.environment,
    ),
    debug: parse_bool_env("HOMELAB_DEBUG", default.debug),
    metadata: load_metadata_from_env(),
  )
}

/// Load configuration from JSON file
pub fn from_json_file(file_path: String) -> Result(NodeConfig, String) {
  case simplifile.read(file_path) {
    Ok(json_content) -> from_json_string(json_content)
    Error(_) -> Error("Failed to read configuration file: " <> file_path)
  }
}

/// Parse configuration from JSON string (simplified implementation)
pub fn from_json_string(_json_string: String) -> Result(NodeConfig, String) {
  // For now, return a default configuration with environment overrides
  // In a future version, we can implement full JSON parsing
  Ok(from_environment())
}

/// Convert configuration to JSON string
pub fn to_json(config: NodeConfig) -> String {
  let config_json =
    json.object([
      #("node_id", json.string(config.node_id)),
      #("node_name", json.string(config.node_name)),
      #("role", role_to_json(config.role)),
      #("capabilities", json.array(config.capabilities, of: json.string)),
      #("network", network_to_json(config.network)),
      #("resources", resource_to_json(config.resources)),
      #("features", feature_to_json(config.features)),
      #("environment", json.string(config.environment)),
      #("debug", json.bool(config.debug)),
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

/// Convert NodeRole to JSON
fn role_to_json(role: NodeRole) -> json.Json {
  case role {
    Coordinator -> json.string("coordinator")
    Gateway -> json.string("gateway")
    Monitor -> json.string("monitor")
    Agent(Generic) -> json.string("agent")
    Agent(Monitoring) -> json.string("agent:monitoring")
    Agent(Storage) -> json.string("agent:storage")
    Agent(Compute) -> json.string("agent:compute")
    Agent(Network) -> json.string("agent:network")
  }
}

/// Convert NetworkConfig to JSON
fn network_to_json(network: NetworkConfig) -> json.Json {
  json.object([
    #("bind_address", json.string(network.bind_address)),
    #("port", json.int(network.port)),
    #("discovery_port", case network.discovery_port {
      Some(port) -> json.int(port)
      None -> json.null()
    }),
    #("external_host", case network.external_host {
      Some(host) -> json.string(host)
      None -> json.null()
    }),
    #("tls_enabled", json.bool(network.tls_enabled)),
    #("max_connections", json.int(network.max_connections)),
  ])
}

/// Convert ResourceConfig to JSON
fn resource_to_json(resources: ResourceConfig) -> json.Json {
  json.object([
    #("max_memory_mb", json.int(resources.max_memory_mb)),
    #("max_cpu_percent", json.int(resources.max_cpu_percent)),
    #("disk_space_mb", json.int(resources.disk_space_mb)),
    #("connection_timeout_ms", json.int(resources.connection_timeout_ms)),
    #("request_timeout_ms", json.int(resources.request_timeout_ms)),
  ])
}

/// Convert FeatureConfig to JSON
fn feature_to_json(features: FeatureConfig) -> json.Json {
  json.object([
    #("clustering", json.bool(features.clustering)),
    #("metrics_collection", json.bool(features.metrics_collection)),
    #("health_checks", json.bool(features.health_checks)),
    #("web_interface", json.bool(features.web_interface)),
    #("api_endpoints", json.bool(features.api_endpoints)),
    #("auto_discovery", json.bool(features.auto_discovery)),
    #("load_balancing", json.bool(features.load_balancing)),
  ])
}

/// Save configuration to JSON file
pub fn save_to_file(
  config: NodeConfig,
  file_path: String,
) -> Result(Nil, String) {
  let json_content = to_json(config)
  case simplifile.write(json_content, to: file_path) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error("Failed to write configuration file: " <> file_path)
  }
}

/// Load complete configuration with multiple source priority
/// Priority: JSON file > Environment variables > Defaults
pub fn load_config(json_file_path: Option(String)) -> NodeConfig {
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
fn merge_configs(base: NodeConfig, override: NodeConfig) -> NodeConfig {
  let default = default_config()

  NodeConfig(
    node_id: case override.node_id == default.node_id {
      True -> base.node_id
      False -> override.node_id
    },
    node_name: case override.node_name == default.node_name {
      True -> base.node_name
      False -> override.node_name
    },
    role: case override.role == default.role {
      True -> base.role
      False -> override.role
    },
    capabilities: case override.capabilities == default.capabilities {
      True -> base.capabilities
      False -> override.capabilities
    },
    network: merge_network_config(base.network, override.network),
    resources: merge_resource_config(base.resources, override.resources),
    features: merge_feature_config(base.features, override.features),
    environment: case override.environment == default.environment {
      True -> base.environment
      False -> override.environment
    },
    debug: case override.debug == default.debug {
      True -> base.debug
      False -> override.debug
    },
    metadata: dict.merge(base.metadata, override.metadata),
  )
}

/// Merge network configurations
fn merge_network_config(
  base: NetworkConfig,
  override: NetworkConfig,
) -> NetworkConfig {
  let default = default_config().network

  NetworkConfig(
    bind_address: case override.bind_address == default.bind_address {
      True -> base.bind_address
      False -> override.bind_address
    },
    port: case override.port == default.port {
      True -> base.port
      False -> override.port
    },
    discovery_port: case override.discovery_port == default.discovery_port {
      True -> base.discovery_port
      False -> override.discovery_port
    },
    external_host: case override.external_host == default.external_host {
      True -> base.external_host
      False -> override.external_host
    },
    tls_enabled: case override.tls_enabled == default.tls_enabled {
      True -> base.tls_enabled
      False -> override.tls_enabled
    },
    max_connections: case override.max_connections == default.max_connections {
      True -> base.max_connections
      False -> override.max_connections
    },
  )
}

/// Merge resource configurations
fn merge_resource_config(
  base: ResourceConfig,
  override: ResourceConfig,
) -> ResourceConfig {
  let default = default_config().resources

  ResourceConfig(
    max_memory_mb: case override.max_memory_mb == default.max_memory_mb {
      True -> base.max_memory_mb
      False -> override.max_memory_mb
    },
    max_cpu_percent: case override.max_cpu_percent == default.max_cpu_percent {
      True -> base.max_cpu_percent
      False -> override.max_cpu_percent
    },
    disk_space_mb: case override.disk_space_mb == default.disk_space_mb {
      True -> base.disk_space_mb
      False -> override.disk_space_mb
    },
    connection_timeout_ms: case
      override.connection_timeout_ms == default.connection_timeout_ms
    {
      True -> base.connection_timeout_ms
      False -> override.connection_timeout_ms
    },
    request_timeout_ms: case
      override.request_timeout_ms == default.request_timeout_ms
    {
      True -> base.request_timeout_ms
      False -> override.request_timeout_ms
    },
  )
}

/// Merge feature configurations
fn merge_feature_config(
  base: FeatureConfig,
  override: FeatureConfig,
) -> FeatureConfig {
  let default = default_config().features

  FeatureConfig(
    clustering: case override.clustering == default.clustering {
      True -> base.clustering
      False -> override.clustering
    },
    metrics_collection: case
      override.metrics_collection == default.metrics_collection
    {
      True -> base.metrics_collection
      False -> override.metrics_collection
    },
    health_checks: case override.health_checks == default.health_checks {
      True -> base.health_checks
      False -> override.health_checks
    },
    web_interface: case override.web_interface == default.web_interface {
      True -> base.web_interface
      False -> override.web_interface
    },
    api_endpoints: case override.api_endpoints == default.api_endpoints {
      True -> base.api_endpoints
      False -> override.api_endpoints
    },
    auto_discovery: case override.auto_discovery == default.auto_discovery {
      True -> base.auto_discovery
      False -> override.auto_discovery
    },
    load_balancing: case override.load_balancing == default.load_balancing {
      True -> base.load_balancing
      False -> override.load_balancing
    },
  )
}

// Helper functions for environment variable parsing

/// Get environment variable with default fallback
fn get_env_with_default(key: String, default: String) -> String {
  case env.string(key) {
    Ok(value) -> value
    Error(_) -> default
  }
}

/// Parse boolean environment variable
fn parse_bool_env(key: String, default: Bool) -> Bool {
  case env.string(key) {
    Ok(value) ->
      case string.lowercase(value) {
        "true" | "1" | "yes" | "on" -> True
        "false" | "0" | "no" | "off" -> False
        _ -> default
      }
    Error(_) -> default
  }
}

/// Parse integer environment variable
fn parse_int_env(key: String, default: Int) -> Int {
  case env.string(key) {
    Ok(value) ->
      case int.parse(value) {
        Ok(parsed_int) -> parsed_int
        Error(_) -> default
      }
    Error(_) -> default
  }
}

/// Parse node role from string
fn parse_node_role(role_str: String) -> NodeRole {
  case string.lowercase(role_str) {
    "coordinator" -> Coordinator
    "gateway" -> Gateway
    "monitor" -> Monitor
    "agent" -> Agent(Generic)
    "agent:monitoring" -> Agent(Monitoring)
    "agent:storage" -> Agent(Storage)
    "agent:compute" -> Agent(Compute)
    "agent:network" -> Agent(Network)
    _ -> Agent(Generic)
  }
}

/// Parse capabilities from comma-separated string
fn parse_capabilities(caps_str: String) -> List(String) {
  string.split(caps_str, ",")
  |> list.map(string.trim)
  |> list.filter(fn(cap) { !string.is_empty(cap) })
}

/// Load network configuration from environment variables
fn load_network_config_from_env() -> NetworkConfig {
  let default = default_config().network

  NetworkConfig(
    bind_address: get_env_with_default(
      "HOMELAB_BIND_ADDRESS",
      default.bind_address,
    ),
    port: parse_int_env("HOMELAB_PORT", default.port),
    discovery_port: case get_env_with_default("HOMELAB_DISCOVERY_PORT", "") {
      "" -> default.discovery_port
      port_str ->
        case int.parse(port_str) {
          Ok(port) -> Some(port)
          Error(_) -> default.discovery_port
        }
    },
    external_host: case get_env_with_default("HOMELAB_EXTERNAL_HOST", "") {
      "" -> default.external_host
      host -> Some(host)
    },
    tls_enabled: parse_bool_env("HOMELAB_TLS_ENABLED", default.tls_enabled),
    max_connections: parse_int_env(
      "HOMELAB_MAX_CONNECTIONS",
      default.max_connections,
    ),
  )
}

/// Load resource configuration from environment variables
fn load_resource_config_from_env() -> ResourceConfig {
  let default = default_config().resources

  ResourceConfig(
    max_memory_mb: parse_int_env("HOMELAB_MAX_MEMORY_MB", default.max_memory_mb),
    max_cpu_percent: parse_int_env(
      "HOMELAB_MAX_CPU_PERCENT",
      default.max_cpu_percent,
    ),
    disk_space_mb: parse_int_env("HOMELAB_DISK_SPACE_MB", default.disk_space_mb),
    connection_timeout_ms: parse_int_env(
      "HOMELAB_CONNECTION_TIMEOUT_MS",
      default.connection_timeout_ms,
    ),
    request_timeout_ms: parse_int_env(
      "HOMELAB_REQUEST_TIMEOUT_MS",
      default.request_timeout_ms,
    ),
  )
}

/// Load feature configuration from environment variables
fn load_feature_config_from_env() -> FeatureConfig {
  let default = default_config().features

  FeatureConfig(
    clustering: parse_bool_env("HOMELAB_CLUSTERING", default.clustering),
    metrics_collection: parse_bool_env(
      "HOMELAB_METRICS_COLLECTION",
      default.metrics_collection,
    ),
    health_checks: parse_bool_env(
      "HOMELAB_HEALTH_CHECKS",
      default.health_checks,
    ),
    web_interface: parse_bool_env(
      "HOMELAB_WEB_INTERFACE",
      default.web_interface,
    ),
    api_endpoints: parse_bool_env(
      "HOMELAB_API_ENDPOINTS",
      default.api_endpoints,
    ),
    auto_discovery: parse_bool_env(
      "HOMELAB_AUTO_DISCOVERY",
      default.auto_discovery,
    ),
    load_balancing: parse_bool_env(
      "HOMELAB_LOAD_BALANCING",
      default.load_balancing,
    ),
  )
}

/// Load metadata from environment variables (prefixed with HOMELAB_META_)
fn load_metadata_from_env() -> Dict(String, String) {
  dict.new()
  |> dict.insert(
    "version",
    get_env_with_default("HOMELAB_META_VERSION", "1.1.0"),
  )
  |> dict.insert(
    "deployment",
    get_env_with_default("HOMELAB_META_DEPLOYMENT", "standalone"),
  )
  |> dict.insert(
    "created_at",
    get_env_with_default("HOMELAB_META_CREATED_AT", "unknown"),
  )
  |> dict.insert(
    "build_info",
    get_env_with_default("HOMELAB_META_BUILD_INFO", "development"),
  )
}

/// Validate configuration and return errors if invalid
pub fn validate_config(config: NodeConfig) -> Result(Nil, List(String)) {
  let errors = []

  let errors = case string.is_empty(config.node_id) {
    True -> ["Node ID cannot be empty", ..errors]
    False -> errors
  }

  let errors = case config.network.port < 1 || config.network.port > 65_535 {
    True -> ["Port must be between 1 and 65535", ..errors]
    False -> errors
  }

  let errors = case config.resources.max_memory_mb <= 0 {
    True -> ["Max memory must be positive", ..errors]
    False -> errors
  }

  let errors = case
    config.resources.max_cpu_percent <= 0
    || config.resources.max_cpu_percent > 100
  {
    True -> ["Max CPU percent must be between 1 and 100", ..errors]
    False -> errors
  }

  case errors {
    [] -> Ok(Nil)
    _ -> Error(list.reverse(errors))
  }
}

/// Get configuration summary as a formatted string
pub fn get_config_summary(config: NodeConfig) -> String {
  "Node Configuration Summary:\n"
  <> "  Node ID: "
  <> config.node_id
  <> "\n"
  <> "  Node Name: "
  <> config.node_name
  <> "\n"
  <> "  Role: "
  <> role_to_string(config.role)
  <> "\n"
  <> "  Environment: "
  <> config.environment
  <> "\n"
  <> "  Network Port: "
  <> int.to_string(config.network.port)
  <> "\n"
  <> "  Debug Mode: "
  <> case config.debug {
    True -> "enabled"
    False -> "disabled"
  }
  <> "\n"
  <> "  Capabilities: "
  <> string.join(config.capabilities, ", ")
}

/// Convert role to human-readable string
fn role_to_string(role: NodeRole) -> String {
  case role {
    Coordinator -> "Coordinator"
    Gateway -> "Gateway"
    Monitor -> "Monitor"
    Agent(Generic) -> "Agent (Generic)"
    Agent(Monitoring) -> "Agent (Monitoring)"
    Agent(Storage) -> "Agent (Storage)"
    Agent(Compute) -> "Agent (Compute)"
    Agent(Network) -> "Agent (Network)"
  }
}
