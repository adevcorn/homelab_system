/// Node configuration module for managing individual node settings
/// Handles JSON-based configuration for node-specific parameters

import gleam/json
import gleam/result
import gleam/option.{type Option}

/// Node configuration type
pub type NodeConfig {
  NodeConfig(
    node_id: String,
    node_name: String,
    role: NodeRole,
    capabilities: List(String),
    network: NetworkConfig,
    resources: ResourceConfig
  )
}

/// Node role types
pub type NodeRole {
  Coordinator
  Agent(agent_type: String)
  Gateway
}

/// Network configuration
pub type NetworkConfig {
  NetworkConfig(
    bind_address: String,
    port: Int,
    discovery_port: Option(Int)
  )
}

/// Resource configuration
pub type ResourceConfig {
  ResourceConfig(
    max_memory_mb: Int,
    max_cpu_percent: Int,
    max_connections: Int
  )
}

/// Create default node configuration
pub fn default_config() -> NodeConfig {
  NodeConfig(
    node_id: "node-1",
    node_name: "homelab-node",
    role: Agent("monitoring"),
    capabilities: ["health_check", "metrics"],
    network: NetworkConfig(
      bind_address: "0.0.0.0",
      port: 4000,
      discovery_port: option.Some(4001)
    ),
    resources: ResourceConfig(
      max_memory_mb: 512,
      max_cpu_percent: 80,
      max_connections: 100
    )
  )
}

/// Load configuration from JSON string
pub fn from_json(json_string: String) -> Result(NodeConfig, String) {
  // Placeholder for JSON parsing implementation
  Ok(default_config())
}

/// Convert configuration to JSON string
pub fn to_json(config: NodeConfig) -> String {
  // Placeholder for JSON serialization implementation
  "{\"node_id\": \"" <> config.node_id <> "\"}"
}