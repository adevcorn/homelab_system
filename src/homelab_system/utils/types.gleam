/// Common types used across the homelab system
/// This module defines shared types and utilities used by multiple modules
/// Universal result type for system operations
pub type SystemResult(success, error) {
  SystemSuccess(success)
  SystemError(error)
}

/// Universal identifier type for system entities
pub type EntityId {
  EntityId(String)
}

/// Node identifier with type safety
pub type NodeId {
  NodeId(String)
}

/// Agent identifier with type safety
pub type AgentId {
  AgentId(String)
}

/// Service identifier with type safety
pub type ServiceId {
  ServiceId(String)
}

/// Task identifier with type safety
pub type TaskId {
  TaskId(String)
}

/// Cluster identifier with type safety
pub type ClusterId {
  ClusterId(String)
}

/// System health status
pub type HealthStatus {
  Healthy
  Degraded
  Unhealthy
  Unknown
}

/// Service status enumeration
pub type ServiceStatus {
  Running
  Stopped
  Starting
  Stopping
  Failed
  Maintenance
}

/// System priority levels
pub type Priority {
  Low
  Medium
  High
  Critical
}

/// Network address information
pub type NetworkAddress {
  NetworkAddress(host: String, port: Int)
}

/// Resource usage information
pub type ResourceUsage {
  ResourceUsage(
    cpu_percent: Float,
    memory_mb: Int,
    disk_mb: Int,
    network_bytes_per_sec: Int,
  )
}

/// Resource limits
pub type ResourceLimits {
  ResourceLimits(
    max_cpu_percent: Float,
    max_memory_mb: Int,
    max_disk_mb: Int,
    max_network_bytes_per_sec: Int,
  )
}

/// Timestamp type (using Unix timestamp)
pub type Timestamp {
  Timestamp(Int)
}

/// Duration in milliseconds
pub type Duration {
  Duration(Int)
}

/// System capability flags
pub type Capability {
  Monitoring
  Storage
  Compute
  Network
  Backup
  Security
  Logging
  Metrics
  WebInterface
  ApiAccess
}

/// System environment types
pub type Environment {
  Development
  Testing
  Staging
  Production
}

/// Error types common across the system
pub type SystemError {
  ConfigurationError(message: String)
  NetworkError(message: String)
  ServiceError(service: String, message: String)
  ClusterError(message: String)
  AuthenticationError(message: String)
  AuthorizationError(message: String)
  ResourceError(resource: String, message: String)
  TimeoutError(operation: String, timeout_ms: Int)
  ValidationError(field: String, message: String)
  UnknownError(message: String)
}

/// System event types for logging and monitoring
pub type SystemEvent {
  NodeJoined(node_id: NodeId, address: NetworkAddress)
  NodeLeft(node_id: NodeId, reason: String)
  ServiceStarted(service_id: ServiceId, node_id: NodeId)
  ServiceStopped(service_id: ServiceId, node_id: NodeId, reason: String)
  ServiceFailed(service_id: ServiceId, node_id: NodeId, error: SystemError)
  AgentRegistered(agent_id: AgentId, capabilities: List(Capability))
  AgentUnregistered(agent_id: AgentId, reason: String)
  TaskStarted(task_id: TaskId, agent_id: AgentId)
  TaskCompleted(task_id: TaskId, agent_id: AgentId, duration: Duration)
  TaskFailed(task_id: TaskId, agent_id: AgentId, error: SystemError)
  HealthStatusChanged(
    entity_id: EntityId,
    old_status: HealthStatus,
    new_status: HealthStatus,
  )
  ResourceThresholdExceeded(
    node_id: NodeId,
    resource: String,
    usage: Float,
    limit: Float,
  )
  ClusterPartition(affected_nodes: List(NodeId))
  ClusterHealed(recovered_nodes: List(NodeId))
}

/// Message envelope for inter-service communication
pub type Message(payload) {
  Message(
    id: String,
    timestamp: Timestamp,
    sender: EntityId,
    recipient: EntityId,
    payload: payload,
    metadata: List(#(String, String)),
  )
}

/// Request/Response pattern types
pub type Request(body) {
  Request(
    id: String,
    timestamp: Timestamp,
    sender: EntityId,
    body: body,
    timeout_ms: Int,
  )
}

pub type Response(body) {
  Response(
    request_id: String,
    timestamp: Timestamp,
    sender: EntityId,
    body: SystemResult(body, SystemError),
  )
}

/// Utility functions for working with common types
/// Convert EntityId to string
pub fn entity_id_to_string(id: EntityId) -> String {
  case id {
    EntityId(s) -> s
  }
}

/// Convert NodeId to string
pub fn node_id_to_string(id: NodeId) -> String {
  case id {
    NodeId(s) -> s
  }
}

/// Convert AgentId to string
pub fn agent_id_to_string(id: AgentId) -> String {
  case id {
    AgentId(s) -> s
  }
}

/// Convert ServiceId to string
pub fn service_id_to_string(id: ServiceId) -> String {
  case id {
    ServiceId(s) -> s
  }
}

/// Convert health status to string
pub fn health_status_to_string(status: HealthStatus) -> String {
  case status {
    Healthy -> "healthy"
    Degraded -> "degraded"
    Unhealthy -> "unhealthy"
    Unknown -> "unknown"
  }
}

/// Convert service status to string
pub fn service_status_to_string(status: ServiceStatus) -> String {
  case status {
    Running -> "running"
    Stopped -> "stopped"
    Starting -> "starting"
    Stopping -> "stopping"
    Failed -> "failed"
    Maintenance -> "maintenance"
  }
}

/// Convert priority to string
pub fn priority_to_string(priority: Priority) -> String {
  case priority {
    Low -> "low"
    Medium -> "medium"
    High -> "high"
    Critical -> "critical"
  }
}

/// Convert capability to string
pub fn capability_to_string(capability: Capability) -> String {
  case capability {
    Monitoring -> "monitoring"
    Storage -> "storage"
    Compute -> "compute"
    Network -> "network"
    Backup -> "backup"
    Security -> "security"
    Logging -> "logging"
    Metrics -> "metrics"
    WebInterface -> "web_interface"
    ApiAccess -> "api_access"
  }
}

/// Convert environment to string
pub fn environment_to_string(env: Environment) -> String {
  case env {
    Development -> "development"
    Testing -> "testing"
    Staging -> "staging"
    Production -> "production"
  }
}

/// Parse string to environment
pub fn string_to_environment(s: String) -> SystemResult(Environment, String) {
  case s {
    "development" -> SystemSuccess(Development)
    "testing" -> SystemSuccess(Testing)
    "staging" -> SystemSuccess(Staging)
    "production" -> SystemSuccess(Production)
    _ -> SystemError("Invalid environment: " <> s)
  }
}

/// Check if a capability is in a list of capabilities
pub fn has_capability(
  capabilities: List(Capability),
  capability: Capability,
) -> Bool {
  case capabilities {
    [] -> False
    [head, ..tail] ->
      case head == capability {
        True -> True
        False -> has_capability(tail, capability)
      }
  }
}

/// Get current timestamp (placeholder implementation)
pub fn now() -> Timestamp {
  // TODO: Implement actual timestamp using erlang time functions
  Timestamp(0)
}

/// Create a duration from seconds
pub fn seconds_to_duration(seconds: Int) -> Duration {
  Duration(seconds * 1000)
}

/// Create a duration from minutes
pub fn minutes_to_duration(minutes: Int) -> Duration {
  Duration(minutes * 60 * 1000)
}

/// Convert duration to seconds
pub fn duration_to_seconds(duration: Duration) -> Int {
  case duration {
    Duration(ms) -> ms / 1000
  }
}
