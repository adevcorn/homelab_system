//// Configuration Validation Module
////
//// This module provides comprehensive validation for both node and cluster
//// configurations. It includes validation rules, error handling, and
//// default value assignment logic.
////
//// Features:
//// - Type-safe validation functions
//// - Comprehensive error reporting
//// - Default value assignment with validation
//// - Cross-configuration consistency checks
//// - Environment-specific validation rules

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp

import gleam/string

import homelab_system/config/cluster_config.{type ClusterConfig}
import homelab_system/config/node_config.{type NodeConfig}

/// Validation result type
pub type ValidationResult {
  ValidationSuccess
  ValidationError(errors: List(String))
}

/// Validation severity levels
pub type ValidationSeverity {
  SeverityError
  SeverityWarning
  SeverityInfo
}

/// Validation issue with details
pub type ValidationIssue {
  ValidationIssue(
    severity: ValidationSeverity,
    field: String,
    message: String,
    current_value: String,
    suggested_value: Option(String),
  )
}

/// Configuration validation context
pub type ValidationContext {
  ValidationContext(
    environment: String,
    strict_mode: Bool,
    allow_warnings: Bool,
    custom_rules: Dict(String, String),
  )
}

/// Network validation patterns
const valid_ip_pattern = "^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"

const valid_hostname_pattern = "^[a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?(\\.([a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?))*$"

const valid_cidr_pattern = "^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/([0-9]|[12][0-9]|3[0-2])$"

/// Create default validation context
pub fn default_validation_context() -> ValidationContext {
  ValidationContext(
    environment: "development",
    strict_mode: False,
    allow_warnings: True,
    custom_rules: dict.new(),
  )
}

/// Create strict validation context for production
pub fn strict_validation_context() -> ValidationContext {
  ValidationContext(
    environment: "production",
    strict_mode: True,
    allow_warnings: False,
    custom_rules: dict.new(),
  )
}

/// Validate node configuration with context
pub fn validate_node_config(
  config: NodeConfig,
  context: ValidationContext,
) -> Result(List(ValidationIssue), String) {
  let issues = []

  let issues = validate_node_id(config.node_id, context, issues)
  let issues = validate_node_name(config.node_name, context, issues)
  let issues = validate_node_capabilities(config.capabilities, context, issues)
  let issues = validate_node_network(config.network, context, issues)
  let issues = validate_node_resources(config.resources, context, issues)
  let issues = validate_node_features(config.features, context, issues)
  let issues = validate_node_metadata(config.metadata, context, issues)

  Ok(list.reverse(issues))
}

/// Validate cluster configuration with context
pub fn validate_cluster_config(
  config: ClusterConfig,
  context: ValidationContext,
) -> Result(List(ValidationIssue), String) {
  let issues = []

  let issues = validate_cluster_id(config.cluster_id, context, issues)
  let issues = validate_cluster_name(config.cluster_name, context, issues)
  let issues = validate_cluster_discovery(config.discovery, context, issues)
  let issues = validate_cluster_networking(config.networking, context, issues)
  let issues =
    validate_cluster_coordination(config.coordination, context, issues)
  let issues = validate_cluster_security(config.security, context, issues)
  let issues = validate_cluster_limits(config.limits, context, issues)
  let issues = validate_cluster_metadata(config.metadata, context, issues)

  Ok(list.reverse(issues))
}

/// Validate both node and cluster configurations for consistency
pub fn validate_configs_consistency(
  node_config: NodeConfig,
  cluster_config: ClusterConfig,
  context: ValidationContext,
) -> Result(List(ValidationIssue), String) {
  let issues = []

  let issues =
    validate_port_conflicts(node_config, cluster_config, context, issues)
  let issues =
    validate_environment_consistency(
      node_config,
      cluster_config,
      context,
      issues,
    )
  let issues =
    validate_security_consistency(node_config, cluster_config, context, issues)
  let issues =
    validate_resource_consistency(node_config, cluster_config, context, issues)

  Ok(list.reverse(issues))
}

/// Check if validation issues contain errors
pub fn has_errors(issues: List(ValidationIssue)) -> Bool {
  list.any(issues, fn(issue) {
    case issue.severity {
      SeverityError -> True
      _ -> False
    }
  })
}

/// Check if validation issues contain warnings
pub fn has_warnings(issues: List(ValidationIssue)) -> Bool {
  list.any(issues, fn(issue) {
    case issue.severity {
      SeverityWarning -> True
      _ -> False
    }
  })
}

/// Filter issues by severity level
pub fn filter_by_severity(
  issues: List(ValidationIssue),
  severity: ValidationSeverity,
) -> List(ValidationIssue) {
  list.filter(issues, fn(issue) { issue.severity == severity })
}

/// Convert validation issues to error strings
/// Convert validation issues to string messages
pub fn issues_to_strings(issues: List(ValidationIssue)) -> List(String) {
  list.map(issues, fn(issue) {
    let severity_str = case issue.severity {
      SeverityError -> "[ERROR]"
      SeverityWarning -> "[WARNING]"
      SeverityInfo -> "[INFO]"
    }
    severity_str <> " " <> issue.field <> ": " <> issue.message
  })
}

/// Format validation issues for display
pub fn format_validation_report(issues: List(ValidationIssue)) -> String {
  case list.is_empty(issues) {
    True -> "Configuration validation passed with no issues."
    False -> {
      let error_count = list.length(filter_by_severity(issues, SeverityError))
      let warning_count =
        list.length(filter_by_severity(issues, SeverityWarning))
      let info_count = list.length(filter_by_severity(issues, SeverityInfo))

      let header =
        "Configuration Validation Report:\n"
        <> "  Errors: "
        <> int.to_string(error_count)
        <> ", Warnings: "
        <> int.to_string(warning_count)
        <> ", Info: "
        <> int.to_string(info_count)
        <> "\n\n"

      let issue_lines =
        list.map(issues, fn(issue) {
          let prefix = case issue.severity {
            SeverityError -> "❌ "
            SeverityWarning -> "⚠️  "
            SeverityInfo -> "ℹ️  "
          }
          prefix <> "[" <> issue.field <> "] " <> issue.message
        })
        |> string.join("\n")

      header <> issue_lines
    }
  }
}

// Node validation functions

/// Validate node ID
fn validate_node_id(
  node_id: String,
  context: ValidationContext,
  issues: List(ValidationIssue),
) -> List(ValidationIssue) {
  let new_issues = []

  let new_issues = case string.is_empty(node_id) {
    True -> [
      ValidationIssue(
        SeverityError,
        "node_id",
        "Node ID cannot be empty",
        "",
        Some("homelab-node-" <> context.environment),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  let new_issues = case string.length(node_id) > 64 {
    True -> [
      ValidationIssue(
        SeverityError,
        "node_id",
        "Node ID cannot exceed 64 characters",
        node_id,
        None,
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  let new_issues = case is_valid_identifier(node_id) {
    False -> [
      ValidationIssue(
        SeverityError,
        "node_id",
        "Node ID must contain only alphanumeric characters and hyphens",
        node_id,
        None,
      ),
      ..new_issues
    ]
    True -> new_issues
  }

  list.append(issues, new_issues)
}

/// Validate node name
fn validate_node_name(
  node_name: String,
  _context: ValidationContext,
  issues: List(ValidationIssue),
) -> List(ValidationIssue) {
  case string.is_empty(node_name) {
    True -> [
      ValidationIssue(
        SeverityWarning,
        "node_name",
        "Node name is empty, using node_id as fallback",
        "",
        Some("Set a descriptive node name"),
      ),
      ..issues
    ]
    False -> issues
  }
}

/// Validate node capabilities
fn validate_node_capabilities(
  capabilities: List(String),
  context: ValidationContext,
  issues: List(ValidationIssue),
) -> List(ValidationIssue) {
  let new_issues = []

  let new_issues = case list.is_empty(capabilities) && context.strict_mode {
    True -> [
      ValidationIssue(
        SeverityWarning,
        "capabilities",
        "No capabilities defined for node",
        "[]",
        Some("[\"health_check\", \"metrics\"]"),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  let invalid_capabilities =
    list.filter(capabilities, fn(cap) { !is_valid_capability(cap) })

  let new_issues = case list.is_empty(invalid_capabilities) {
    True -> new_issues
    False -> [
      ValidationIssue(
        SeverityError,
        "capabilities",
        "Invalid capabilities: " <> string.join(invalid_capabilities, ", "),
        string.join(capabilities, ", "),
        Some("Use valid capability names"),
      ),
      ..new_issues
    ]
  }

  list.append(issues, new_issues)
}

/// Validate node network configuration
fn validate_node_network(
  network: node_config.NetworkConfig,
  context: ValidationContext,
  issues: List(ValidationIssue),
) -> List(ValidationIssue) {
  let new_issues = []

  let new_issues = case is_valid_port(network.port) {
    False -> [
      ValidationIssue(
        SeverityError,
        "network.port",
        "Port must be between 1 and 65535",
        int.to_string(network.port),
        Some("4000"),
      ),
      ..new_issues
    ]
    True -> new_issues
  }

  let new_issues = case network.discovery_port {
    Some(port) ->
      case is_valid_port(port) {
        False -> [
          ValidationIssue(
            SeverityError,
            "network.discovery_port",
            "Discovery port must be between 1 and 65535",
            int.to_string(port),
            Some("4001"),
          ),
          ..new_issues
        ]
        True -> new_issues
      }
    None -> new_issues
  }

  let new_issues = case is_valid_bind_address(network.bind_address) {
    False -> [
      ValidationIssue(
        SeverityError,
        "network.bind_address",
        "Invalid bind address format",
        network.bind_address,
        Some("0.0.0.0"),
      ),
      ..new_issues
    ]
    True -> new_issues
  }

  let new_issues = case network.max_connections <= 0 {
    True -> [
      ValidationIssue(
        SeverityError,
        "network.max_connections",
        "Max connections must be positive",
        int.to_string(network.max_connections),
        Some("100"),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  let new_issues = case
    context.environment == "production" && !network.tls_enabled
  {
    True -> [
      ValidationIssue(
        SeverityWarning,
        "network.tls_enabled",
        "TLS should be enabled in production environment",
        "false",
        Some("true"),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  list.append(issues, new_issues)
}

/// Validate node resource configuration
fn validate_node_resources(
  resources: node_config.ResourceConfig,
  _context: ValidationContext,
  issues: List(ValidationIssue),
) -> List(ValidationIssue) {
  let new_issues = []

  let new_issues = case resources.max_memory_mb <= 0 {
    True -> [
      ValidationIssue(
        SeverityError,
        "resources.max_memory_mb",
        "Max memory must be positive",
        int.to_string(resources.max_memory_mb),
        Some("512"),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  let new_issues = case
    resources.max_cpu_percent <= 0 || resources.max_cpu_percent > 100
  {
    True -> [
      ValidationIssue(
        SeverityError,
        "resources.max_cpu_percent",
        "Max CPU percent must be between 1 and 100",
        int.to_string(resources.max_cpu_percent),
        Some("80"),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  let new_issues = case resources.connection_timeout_ms <= 0 {
    True -> [
      ValidationIssue(
        SeverityError,
        "resources.connection_timeout_ms",
        "Connection timeout must be positive",
        int.to_string(resources.connection_timeout_ms),
        Some("30000"),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  let new_issues = case resources.request_timeout_ms <= 0 {
    True -> [
      ValidationIssue(
        SeverityError,
        "resources.request_timeout_ms",
        "Request timeout must be positive",
        int.to_string(resources.request_timeout_ms),
        Some("5000"),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  list.append(issues, new_issues)
}

/// Validate node feature configuration
fn validate_node_features(
  features: node_config.FeatureConfig,
  context: ValidationContext,
  issues: List(ValidationIssue),
) -> List(ValidationIssue) {
  case context.environment == "production" && !features.health_checks {
    True -> [
      ValidationIssue(
        SeverityWarning,
        "features.health_checks",
        "Health checks should be enabled in production",
        "false",
        Some("true"),
      ),
      ..issues
    ]
    False -> issues
  }
}

/// Validate node metadata
fn validate_node_metadata(
  metadata: Dict(String, String),
  _context: ValidationContext,
  issues: List(ValidationIssue),
) -> List(ValidationIssue) {
  let metadata_size = dict.size(metadata)
  case metadata_size > 100 {
    True -> [
      ValidationIssue(
        SeverityWarning,
        "metadata",
        "Large number of metadata entries may impact performance",
        int.to_string(metadata_size) <> " entries",
        Some("Consider reducing metadata entries"),
      ),
      ..issues
    ]
    False -> issues
  }
}

// Cluster validation functions

/// Validate cluster ID
fn validate_cluster_id(
  cluster_id: String,
  context: ValidationContext,
  issues: List(ValidationIssue),
) -> List(ValidationIssue) {
  let new_issues = []

  let new_issues = case string.is_empty(cluster_id) {
    True -> [
      ValidationIssue(
        SeverityError,
        "cluster_id",
        "Cluster ID cannot be empty",
        "",
        Some("homelab-cluster-" <> context.environment),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  let new_issues = case is_valid_identifier(cluster_id) {
    False -> [
      ValidationIssue(
        SeverityError,
        "cluster_id",
        "Cluster ID must contain only alphanumeric characters and hyphens",
        cluster_id,
        None,
      ),
      ..new_issues
    ]
    True -> new_issues
  }

  list.append(issues, new_issues)
}

/// Validate cluster name
fn validate_cluster_name(
  cluster_name: String,
  _context: ValidationContext,
  issues: List(ValidationIssue),
) -> List(ValidationIssue) {
  case string.is_empty(cluster_name) {
    True -> [
      ValidationIssue(
        SeverityError,
        "cluster_name",
        "Cluster name cannot be empty",
        "",
        Some("homelab-cluster"),
      ),
      ..issues
    ]
    False -> issues
  }
}

/// Validate cluster discovery configuration
fn validate_cluster_discovery(
  discovery: cluster_config.DiscoveryConfig,
  context: ValidationContext,
  issues: List(ValidationIssue),
) -> List(ValidationIssue) {
  let new_issues = []

  let new_issues = case is_valid_port(discovery.discovery_port) {
    False -> [
      ValidationIssue(
        SeverityError,
        "discovery.discovery_port",
        "Discovery port must be between 1 and 65535",
        int.to_string(discovery.discovery_port),
        Some("4001"),
      ),
      ..new_issues
    ]
    True -> new_issues
  }

  let new_issues = case list.is_empty(discovery.bootstrap_nodes) {
    True -> [
      ValidationIssue(
        SeverityWarning,
        "discovery.bootstrap_nodes",
        "No bootstrap nodes configured",
        "[]",
        Some("[\"localhost:4001\"]"),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  let invalid_nodes =
    list.filter(discovery.bootstrap_nodes, fn(node) {
      !is_valid_node_address(node)
    })

  let new_issues = case list.is_empty(invalid_nodes) {
    True -> new_issues
    False -> [
      ValidationIssue(
        SeverityError,
        "discovery.bootstrap_nodes",
        "Invalid bootstrap node addresses: " <> string.join(invalid_nodes, ", "),
        string.join(discovery.bootstrap_nodes, ", "),
        Some("Use format: host:port"),
      ),
      ..new_issues
    ]
  }

  let new_issues = case discovery.heartbeat_interval_ms <= 0 {
    True -> [
      ValidationIssue(
        SeverityError,
        "discovery.heartbeat_interval_ms",
        "Heartbeat interval must be positive",
        int.to_string(discovery.heartbeat_interval_ms),
        Some("5000"),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  let new_issues = case
    context.environment == "production"
    && discovery.heartbeat_interval_ms < 1000
  {
    True -> [
      ValidationIssue(
        SeverityWarning,
        "discovery.heartbeat_interval_ms",
        "Very short heartbeat interval may impact performance in production",
        int.to_string(discovery.heartbeat_interval_ms),
        Some("5000"),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  list.append(issues, new_issues)
}

/// Validate cluster networking configuration
fn validate_cluster_networking(
  networking: cluster_config.ClusterNetworkConfig,
  context: ValidationContext,
  issues: List(ValidationIssue),
) -> List(ValidationIssue) {
  let new_issues = []

  let new_issues = case
    networking.cluster_port_range_end <= networking.cluster_port_range_start
  {
    True -> [
      ValidationIssue(
        SeverityError,
        "networking.cluster_port_range",
        "Port range end must be greater than start",
        int.to_string(networking.cluster_port_range_start)
          <> "-"
          <> int.to_string(networking.cluster_port_range_end),
        Some("5000-5999"),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  let new_issues = case
    context.environment == "production" && !networking.inter_node_encryption
  {
    True -> [
      ValidationIssue(
        SeverityWarning,
        "networking.inter_node_encryption",
        "Inter-node encryption should be enabled in production",
        "false",
        Some("true"),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  let invalid_networks =
    list.filter(networking.allowed_networks, fn(network) {
      !is_valid_cidr(network)
    })

  let new_issues = case list.is_empty(invalid_networks) {
    True -> new_issues
    False -> [
      ValidationIssue(
        SeverityError,
        "networking.allowed_networks",
        "Invalid CIDR networks: " <> string.join(invalid_networks, ", "),
        string.join(networking.allowed_networks, ", "),
        Some("Use CIDR notation: 192.168.1.0/24"),
      ),
      ..new_issues
    ]
  }

  list.append(issues, new_issues)
}

/// Validate cluster coordination configuration
fn validate_cluster_coordination(
  coordination: cluster_config.CoordinationConfig,
  _context: ValidationContext,
  issues: List(ValidationIssue),
) -> List(ValidationIssue) {
  let new_issues = []

  let new_issues = case coordination.election_timeout_ms <= 0 {
    True -> [
      ValidationIssue(
        SeverityError,
        "coordination.election_timeout_ms",
        "Election timeout must be positive",
        int.to_string(coordination.election_timeout_ms),
        Some("10000"),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  let new_issues = case
    coordination.heartbeat_timeout_ms >= coordination.election_timeout_ms
  {
    True -> [
      ValidationIssue(
        SeverityWarning,
        "coordination.heartbeat_timeout_ms",
        "Heartbeat timeout should be less than election timeout",
        int.to_string(coordination.heartbeat_timeout_ms),
        Some(int.to_string(coordination.election_timeout_ms / 2)),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  let new_issues = case coordination.quorum_size {
    Some(size) ->
      case size <= 0 {
        True -> [
          ValidationIssue(
            SeverityError,
            "coordination.quorum_size",
            "Quorum size must be positive",
            int.to_string(size),
            Some("3"),
          ),
          ..new_issues
        ]
        False -> new_issues
      }
    None -> new_issues
  }

  list.append(issues, new_issues)
}

/// Validate cluster security configuration
fn validate_cluster_security(
  security: cluster_config.SecurityConfig,
  context: ValidationContext,
  issues: List(ValidationIssue),
) -> List(ValidationIssue) {
  let new_issues = []

  let new_issues = case
    context.environment == "production"
    && !security.authentication_enabled
    && context.strict_mode
  {
    True -> [
      ValidationIssue(
        SeverityError,
        "security.authentication_enabled",
        "Authentication must be enabled in production strict mode",
        "false",
        Some("true"),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  let new_issues = case
    security.authentication_enabled && !security.authorization_enabled
  {
    True -> [
      ValidationIssue(
        SeverityWarning,
        "security.authorization_enabled",
        "Authorization should be enabled when authentication is enabled",
        "false",
        Some("true"),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  list.append(issues, new_issues)
}

/// Validate cluster limits configuration
fn validate_cluster_limits(
  limits: cluster_config.ClusterLimits,
  _context: ValidationContext,
  issues: List(ValidationIssue),
) -> List(ValidationIssue) {
  let new_issues = []

  let new_issues = case limits.max_nodes <= 0 {
    True -> [
      ValidationIssue(
        SeverityError,
        "limits.max_nodes",
        "Max nodes must be positive",
        int.to_string(limits.max_nodes),
        Some("10"),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  let new_issues = case limits.max_tasks_per_node <= 0 {
    True -> [
      ValidationIssue(
        SeverityError,
        "limits.max_tasks_per_node",
        "Max tasks per node must be positive",
        int.to_string(limits.max_tasks_per_node),
        Some("100"),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  let new_issues = case limits.connection_pool_size <= 0 {
    True -> [
      ValidationIssue(
        SeverityError,
        "limits.connection_pool_size",
        "Connection pool size must be positive",
        int.to_string(limits.connection_pool_size),
        Some("50"),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  list.append(issues, new_issues)
}

/// Validate cluster metadata
fn validate_cluster_metadata(
  metadata: Dict(String, String),
  _context: ValidationContext,
  issues: List(ValidationIssue),
) -> List(ValidationIssue) {
  let metadata_size = dict.size(metadata)
  case metadata_size > 50 {
    True -> [
      ValidationIssue(
        SeverityInfo,
        "metadata",
        "Large cluster metadata may impact synchronization",
        int.to_string(metadata_size) <> " entries",
        Some("Consider reducing metadata entries"),
      ),
      ..issues
    ]
    False -> issues
  }
}

// Consistency validation functions

/// Validate port conflicts between node and cluster configurations
fn validate_port_conflicts(
  node_config: NodeConfig,
  cluster_config: ClusterConfig,
  _context: ValidationContext,
  issues: List(ValidationIssue),
) -> List(ValidationIssue) {
  let node_port = node_config.network.port
  let cluster_start = cluster_config.networking.cluster_port_range_start
  let cluster_end = cluster_config.networking.cluster_port_range_end
  let discovery_port = cluster_config.discovery.discovery_port

  let new_issues = []

  let new_issues = case node_port == discovery_port {
    True -> [
      ValidationIssue(
        SeverityError,
        "port_conflict",
        "Node port conflicts with cluster discovery port",
        int.to_string(node_port),
        Some("Use different ports"),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  let new_issues = case node_port >= cluster_start && node_port <= cluster_end {
    True -> [
      ValidationIssue(
        SeverityWarning,
        "port_conflict",
        "Node port is within cluster port range",
        int.to_string(node_port),
        Some(
          "Use port outside range "
          <> int.to_string(cluster_start)
          <> "-"
          <> int.to_string(cluster_end),
        ),
      ),
      ..new_issues
    ]
    False -> new_issues
  }

  list.append(issues, new_issues)
}

/// Validate environment consistency
fn validate_environment_consistency(
  node_config: NodeConfig,
  cluster_config: ClusterConfig,
  _context: ValidationContext,
  issues: List(ValidationIssue),
) -> List(ValidationIssue) {
  case node_config.environment != cluster_config.environment {
    True -> [
      ValidationIssue(
        SeverityWarning,
        "environment_mismatch",
        "Node and cluster environments don't match",
        "Node: "
          <> node_config.environment
          <> ", Cluster: "
          <> cluster_config.environment,
        Some("Ensure both configurations use the same environment"),
      ),
      ..issues
    ]
    False -> issues
  }
}

/// Validate security consistency
fn validate_security_consistency(
  node_config: NodeConfig,
  cluster_config: ClusterConfig,
  _context: ValidationContext,
  issues: List(ValidationIssue),
) -> List(ValidationIssue) {
  case
    node_config.network.tls_enabled
    != cluster_config.security.secure_communication
  {
    True -> [
      ValidationIssue(
        SeverityWarning,
        "security_mismatch",
        "Node TLS and cluster secure communication settings don't match",
        "Node TLS: "
          <> case node_config.network.tls_enabled {
          True -> "enabled"
          False -> "disabled"
        }
          <> ", Cluster: "
          <> case cluster_config.security.secure_communication {
          True -> "enabled"
          False -> "disabled"
        },
        Some("Enable TLS on both node and cluster"),
      ),
      ..issues
    ]
    False -> issues
  }
}

/// Validate resource consistency
fn validate_resource_consistency(
  node_config: NodeConfig,
  cluster_config: ClusterConfig,
  _context: ValidationContext,
  issues: List(ValidationIssue),
) -> List(ValidationIssue) {
  let node_memory_gb = node_config.resources.max_memory_mb / 1024
  let cluster_memory_gb = cluster_config.limits.max_memory_per_cluster_gb
  let max_nodes = cluster_config.limits.max_nodes

  case node_memory_gb * max_nodes > cluster_memory_gb {
    True -> [
      ValidationIssue(
        SeverityWarning,
        "resource_mismatch",
        "Total node memory may exceed cluster memory limit",
        "Node: "
          <> int.to_string(node_memory_gb)
          <> "GB x "
          <> int.to_string(max_nodes)
          <> " nodes",
        Some("Adjust cluster memory limit or node memory allocation"),
      ),
      ..issues
    ]
    False -> issues
  }
}

// Helper validation functions

/// Check if identifier is valid (alphanumeric and hyphens only)
fn is_valid_identifier(identifier: String) -> Bool {
  case regexp.from_string("^[a-zA-Z0-9-]+$") {
    Ok(pattern) -> regexp.check(pattern, identifier)
    Error(_) -> False
  }
}

/// Check if port is valid (1-65535)
fn is_valid_port(port: Int) -> Bool {
  port >= 1 && port <= 65_535
}

/// Check if bind address is valid (IP or hostname)
fn is_valid_bind_address(address: String) -> Bool {
  case address {
    "0.0.0.0" | "127.0.0.1" | "localhost" -> True
    _ -> is_valid_ip(address) || is_valid_hostname(address)
  }
}

/// Check if IP address is valid
fn is_valid_ip(ip: String) -> Bool {
  case regexp.from_string(valid_ip_pattern) {
    Ok(pattern) -> regexp.check(pattern, ip)
    Error(_) -> False
  }
}

/// Check if hostname is valid
fn is_valid_hostname(hostname: String) -> Bool {
  case regexp.from_string(valid_hostname_pattern) {
    Ok(pattern) -> regexp.check(pattern, hostname)
    Error(_) -> False
  }
}

/// Check if CIDR network notation is valid
fn is_valid_cidr(cidr: String) -> Bool {
  case regexp.from_string(valid_cidr_pattern) {
    Ok(pattern) -> regexp.check(pattern, cidr)
    Error(_) -> False
  }
}

/// Check if node address is valid (host:port format)
fn is_valid_node_address(address: String) -> Bool {
  case string.split(address, ":") {
    [host, port_str] -> {
      case int.parse(port_str) {
        Ok(port) -> {
          let valid_host =
            is_valid_ip(host) || is_valid_hostname(host) || host == "localhost"
          let valid_port = is_valid_port(port)
          valid_host && valid_port
        }
        Error(_) -> False
      }
    }
    _ -> False
  }
}

/// Check if capability name is valid
fn is_valid_capability(capability: String) -> Bool {
  let valid_capabilities = [
    "health_check",
    "metrics",
    "monitoring",
    "storage",
    "compute",
    "network",
    "admin",
    "config",
    "api",
    "web",
    "cli",
    "logging",
    "tracing",
    "backup",
    "security",
    "discovery",
    "coordination",
  ]
  list.contains(valid_capabilities, capability)
}

/// Apply default values to node configuration based on validation context
pub fn apply_node_defaults(
  config: NodeConfig,
  context: ValidationContext,
) -> NodeConfig {
  let updated_config = case string.is_empty(config.node_id) {
    True ->
      node_config.NodeConfig(
        ..config,
        node_id: "homelab-node-" <> context.environment,
      )
    False -> config
  }

  let updated_config = case string.is_empty(updated_config.node_name) {
    True ->
      node_config.NodeConfig(
        ..updated_config,
        node_name: updated_config.node_id,
      )
    False -> updated_config
  }

  let updated_config = case list.is_empty(updated_config.capabilities) {
    True ->
      node_config.NodeConfig(..updated_config, capabilities: [
        "health_check",
        "metrics",
      ])
    False -> updated_config
  }

  updated_config
}

/// Apply default values to cluster configuration based on validation context
pub fn apply_cluster_defaults(
  config: ClusterConfig,
  context: ValidationContext,
) -> ClusterConfig {
  let updated_config = case string.is_empty(config.cluster_id) {
    True ->
      cluster_config.ClusterConfig(
        ..config,
        cluster_id: "homelab-cluster-" <> context.environment,
      )
    False -> config
  }

  let updated_config = case string.is_empty(updated_config.cluster_name) {
    True ->
      cluster_config.ClusterConfig(
        ..updated_config,
        cluster_name: "homelab-cluster",
      )
    False -> updated_config
  }

  let updated_config = case
    list.is_empty(updated_config.discovery.bootstrap_nodes)
  {
    True ->
      cluster_config.ClusterConfig(
        ..updated_config,
        discovery: cluster_config.DiscoveryConfig(
          ..updated_config.discovery,
          bootstrap_nodes: ["localhost:4001"],
        ),
      )
    False -> updated_config
  }

  updated_config
}

/// Validate and fix configuration automatically where possible
pub fn validate_and_fix_node_config(
  config: NodeConfig,
  context: ValidationContext,
) -> Result(NodeConfig, List(ValidationIssue)) {
  let fixed_config = apply_node_defaults(config, context)

  case validate_node_config(fixed_config, context) {
    Ok(issues) -> {
      case has_errors(issues) {
        True -> Error(issues)
        False -> Ok(fixed_config)
      }
    }
    Error(msg) ->
      Error([
        ValidationIssue(
          SeverityError,
          "validation",
          "Validation failed: " <> msg,
          "",
          None,
        ),
      ])
  }
}

/// Validate and fix cluster configuration automatically where possible
pub fn validate_and_fix_cluster_config(
  config: ClusterConfig,
  context: ValidationContext,
) -> Result(ClusterConfig, List(ValidationIssue)) {
  let fixed_config = apply_cluster_defaults(config, context)

  case validate_cluster_config(fixed_config, context) {
    Ok(issues) -> {
      case has_errors(issues) {
        True -> Error(issues)
        False -> Ok(fixed_config)
      }
    }
    Error(msg) ->
      Error([
        ValidationIssue(
          SeverityError,
          "validation",
          "Validation failed: " <> msg,
          "",
          None,
        ),
      ])
  }
}
