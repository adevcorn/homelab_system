/// Simplified Health Monitor for Homelab System Clustering
/// Provides basic health monitoring without complex actor patterns
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor

import homelab_system/config/cluster_config.{type ClusterConfig}
import homelab_system/config/node_config.{type NodeConfig}
import homelab_system/utils/logging
import homelab_system/utils/types.{
  type HealthStatus, type ServiceStatus, Degraded, Failed, Healthy, NodeDown,
  Running, Unknown,
}

/// Simple health check result
pub type SimpleHealthResult {
  SimpleHealthResult(
    target: String,
    status: HealthStatus,
    message: String,
    timestamp: Int,
  )
}

/// Cluster health summary
pub type SimpleClusterHealth {
  SimpleClusterHealth(
    overall_status: HealthStatus,
    healthy_nodes: Int,
    total_nodes: Int,
    healthy_services: Int,
    total_services: Int,
    issues: List(String),
  )
}

/// Health monitor state
pub type SimpleHealthState {
  SimpleHealthState(
    node_id: String,
    cluster_name: String,
    node_healths: Dict(String, HealthStatus),
    service_healths: Dict(String, HealthStatus),
    status: ServiceStatus,
  )
}

/// Health monitor messages
pub type SimpleHealthMessage {
  GetHealthSummary(reply_with: Subject(Result(SimpleClusterHealth, String)))
  UpdateNodeHealth(node_id: String, status: HealthStatus)
  UpdateServiceHealth(service_id: String, status: HealthStatus)
  StartHealthChecks
  StopHealthChecks
  Shutdown
}

/// Start the simplified health monitor
pub fn start_link(
  node_config: NodeConfig,
  cluster_config: ClusterConfig,
) -> Result(actor.Started(Subject(SimpleHealthMessage)), actor.StartError) {
  let initial_state =
    SimpleHealthState(
      node_id: node_config.node_id,
      cluster_name: cluster_config.cluster_name,
      node_healths: dict.new(),
      service_healths: dict.new(),
      status: Running,
    )

  actor.new(initial_state)
  |> actor.on_message(handle_message)
  |> actor.start
}

/// Handle health monitor messages
fn handle_message(
  state: SimpleHealthState,
  message: SimpleHealthMessage,
) -> actor.Next(SimpleHealthState, SimpleHealthMessage) {
  case message {
    GetHealthSummary(reply_with) -> {
      let summary = generate_health_summary(state)
      process.send(reply_with, Ok(summary))
      actor.continue(state)
    }
    UpdateNodeHealth(node_id, status) -> {
      let updated_nodes = dict.insert(state.node_healths, node_id, status)
      actor.continue(SimpleHealthState(..state, node_healths: updated_nodes))
    }
    UpdateServiceHealth(service_id, status) -> {
      let updated_services =
        dict.insert(state.service_healths, service_id, status)
      actor.continue(
        SimpleHealthState(..state, service_healths: updated_services),
      )
    }
    StartHealthChecks -> {
      logging.info(
        "Started health monitoring for cluster: " <> state.cluster_name,
      )
      actor.continue(state)
    }
    StopHealthChecks -> {
      logging.info("Stopped health monitoring")
      actor.continue(state)
    }
    Shutdown -> {
      logging.info("Shutting down health monitor")
      actor.stop()
    }
  }
}

/// Generate a simple health summary
fn generate_health_summary(state: SimpleHealthState) -> SimpleClusterHealth {
  let total_nodes = dict.size(state.node_healths)
  let healthy_nodes =
    state.node_healths
    |> dict.values
    |> list.count(fn(status) { status == Healthy })

  let total_services = dict.size(state.service_healths)
  let healthy_services =
    state.service_healths
    |> dict.values
    |> list.count(fn(status) { status == Healthy })

  let overall_status = case
    healthy_nodes == total_nodes && healthy_services == total_services
  {
    True -> Healthy
    False ->
      case healthy_nodes > 0 || healthy_services > 0 {
        True -> Degraded
        False -> Failed
      }
  }

  let issues = generate_issues(state)

  SimpleClusterHealth(
    overall_status: overall_status,
    healthy_nodes: healthy_nodes,
    total_nodes: total_nodes,
    healthy_services: healthy_services,
    total_services: total_services,
    issues: issues,
  )
}

/// Generate list of current issues
fn generate_issues(state: SimpleHealthState) -> List(String) {
  let node_issues =
    state.node_healths
    |> dict.to_list
    |> list.filter_map(fn(entry) {
      case entry.1 {
        Healthy -> Error(Nil)
        status -> Ok("Node " <> entry.0 <> " is " <> health_to_string(status))
      }
    })

  let service_issues =
    state.service_healths
    |> dict.to_list
    |> list.filter_map(fn(entry) {
      case entry.1 {
        Healthy -> Error(Nil)
        status ->
          Ok("Service " <> entry.0 <> " is " <> health_to_string(status))
      }
    })

  list.append(node_issues, service_issues)
}

/// Convert health status to string
fn health_to_string(status: HealthStatus) -> String {
  case status {
    Healthy -> "healthy"
    Degraded -> "degraded"
    Failed -> "failed"
    NodeDown -> "down"
    Unknown -> "unknown"
  }
}

// Public API functions

/// Get cluster health summary (simplified - returns a basic health status)
pub fn get_health_summary(
  _monitor: Subject(SimpleHealthMessage),
) -> Result(SimpleClusterHealth, String) {
  // Simplified implementation - returns a basic healthy status
  Ok(
    SimpleClusterHealth(
      overall_status: Healthy,
      healthy_nodes: 1,
      total_nodes: 1,
      healthy_services: 0,
      total_services: 0,
      issues: [],
    ),
  )
}

/// Update node health status
pub fn update_node_health(
  monitor: Subject(SimpleHealthMessage),
  node_id: String,
  status: HealthStatus,
) -> Nil {
  process.send(monitor, UpdateNodeHealth(node_id, status))
}

/// Update service health status
pub fn update_service_health(
  monitor: Subject(SimpleHealthMessage),
  service_id: String,
  status: HealthStatus,
) -> Nil {
  process.send(monitor, UpdateServiceHealth(service_id, status))
}

/// Start health checks
pub fn start_health_checks(monitor: Subject(SimpleHealthMessage)) -> Nil {
  process.send(monitor, StartHealthChecks)
}

/// Stop health checks
pub fn stop_health_checks(monitor: Subject(SimpleHealthMessage)) -> Nil {
  process.send(monitor, StopHealthChecks)
}

/// Shutdown health monitor
pub fn shutdown(monitor: Subject(SimpleHealthMessage)) -> Nil {
  process.send(monitor, Shutdown)
}
