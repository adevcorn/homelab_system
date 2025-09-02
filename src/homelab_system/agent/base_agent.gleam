/// Enhanced base agent module with correct OTP actor API
/// Provides a foundation for creating specialized agents in the homelab system
import gleam/erlang/process
import gleam/list
import gleam/option.{type Option}
import gleam/otp/actor
import homelab_system/config/node_config.{type NodeConfig}
import homelab_system/utils/logging
import homelab_system/utils/types.{
  type AgentId, type Capability, type HealthStatus, type ServiceStatus,
  type Timestamp,
}

/// Agent configuration type
pub type AgentConfig {
  AgentConfig(
    id: AgentId,
    name: String,
    capabilities: List(Capability),
    max_concurrent_tasks: Int,
    heartbeat_interval_ms: Int,
    health_check_interval_ms: Int,
  )
}

/// Agent state type for OTP actor
pub type AgentState {
  AgentState(
    config: AgentConfig,
    status: ServiceStatus,
    health: HealthStatus,
    current_tasks: List(TaskInfo),
    metadata: Option(String),
    node_config: NodeConfig,
    last_heartbeat: Timestamp,
    statistics: AgentStatistics,
  )
}

/// Task information tracked by the agent
pub type TaskInfo {
  TaskInfo(
    task_id: String,
    started_at: Timestamp,
    task_type: String,
    priority: types.Priority,
  )
}

/// Agent statistics
pub type AgentStatistics {
  AgentStatistics(
    tasks_completed: Int,
    tasks_failed: Int,
    total_uptime_seconds: Int,
    average_task_duration_ms: Int,
  )
}

/// Messages that can be sent to the agent actor
pub type AgentMessage {
  StartTask(task_id: String, task_type: String, priority: types.Priority)
  CompleteTask(task_id: String, success: Bool)
  UpdateStatus(new_status: ServiceStatus)
  HealthCheck
  GetStatus
  GetStatistics
  Shutdown
  Heartbeat
}

/// Start an agent actor with the given configuration
pub fn start_link(
  node_config: NodeConfig,
) -> Result(actor.Started(process.Subject(AgentMessage)), actor.StartError) {
  let config = create_agent_config_from_node(node_config)

  let initial_state =
    AgentState(
      config: config,
      status: types.Starting,
      health: types.Unknown,
      current_tasks: [],
      metadata: option.None,
      node_config: node_config,
      last_heartbeat: types.now(),
      statistics: AgentStatistics(
        tasks_completed: 0,
        tasks_failed: 0,
        total_uptime_seconds: 0,
        average_task_duration_ms: 0,
      ),
    )

  case
    actor.new(initial_state)
    |> actor.on_message(handle_message)
    |> actor.start
  {
    Ok(started) -> {
      logging.log_agent_registration(
        types.agent_id_to_string(config.id),
        get_agent_type_string(node_config),
        format_capabilities(config.capabilities),
      )
      Ok(started)
    }
    Error(err) -> Error(err)
  }
}

/// Create agent configuration from node configuration
fn create_agent_config_from_node(node_config: NodeConfig) -> AgentConfig {
  let agent_id = types.AgentId(node_config.node_id <> "_agent")
  let capabilities = get_capabilities_from_node_role(node_config.role)

  AgentConfig(
    id: agent_id,
    name: node_config.node_name <> " Agent",
    capabilities: capabilities,
    max_concurrent_tasks: 5,
    heartbeat_interval_ms: 30_000,
    health_check_interval_ms: 60_000,
  )
}

/// Get capabilities based on node role
fn get_capabilities_from_node_role(
  role: node_config.NodeRole,
) -> List(Capability) {
  case role {
    node_config.Agent(agent_type) ->
      case agent_type {
        node_config.Monitoring -> [
          types.Monitoring,
          types.Metrics,
          types.Logging,
        ]
        node_config.Storage -> [types.Storage, types.Backup]
        node_config.Compute -> [types.Compute]
        node_config.Network -> [types.Network, types.Monitoring]
        node_config.Generic -> [types.Monitoring, types.Compute]
      }
    node_config.Coordinator -> [types.Monitoring, types.Metrics, types.Logging]
    node_config.Gateway -> [types.Network, types.ApiAccess, types.WebInterface]
    node_config.Monitor -> [types.Monitoring, types.Metrics, types.Logging]
  }
}

/// Get agent type as string for logging
fn get_agent_type_string(node_config: NodeConfig) -> String {
  case node_config.role {
    node_config.Agent(agent_type) ->
      case agent_type {
        node_config.Monitoring -> "monitoring"
        node_config.Storage -> "storage"
        node_config.Compute -> "compute"
        node_config.Network -> "network"
        node_config.Generic -> "generic"
      }
    node_config.Coordinator -> "coordinator"
    node_config.Gateway -> "gateway"
    node_config.Monitor -> "monitor"
  }
}

/// Format capabilities list for logging
fn format_capabilities(capabilities: List(Capability)) -> String {
  capabilities
  |> list.map(types.capability_to_string)
  |> list.fold("", fn(acc, cap) {
    case acc {
      "" -> cap
      _ -> acc <> "," <> cap
    }
  })
}

/// Handle incoming messages to the agent actor
fn handle_message(
  state: AgentState,
  message: AgentMessage,
) -> actor.Next(AgentState, AgentMessage) {
  case message {
    StartTask(task_id, task_type, priority) ->
      handle_start_task(task_id, task_type, priority, state)

    CompleteTask(task_id, success) ->
      handle_complete_task(task_id, success, state)

    UpdateStatus(new_status) -> handle_update_status(new_status, state)

    HealthCheck -> handle_health_check(state)

    GetStatus -> handle_get_status(state)

    GetStatistics -> handle_get_statistics(state)

    Heartbeat -> handle_heartbeat(state)

    Shutdown -> handle_shutdown(state)
  }
}

/// Handle starting a new task
fn handle_start_task(
  task_id: String,
  task_type: String,
  priority: types.Priority,
  state: AgentState,
) -> actor.Next(AgentState, AgentMessage) {
  case can_accept_task(state) {
    True -> {
      let task_info =
        TaskInfo(
          task_id: task_id,
          started_at: types.now(),
          task_type: task_type,
          priority: priority,
        )

      let new_tasks = [task_info, ..state.current_tasks]
      let new_state = AgentState(..state, current_tasks: new_tasks)

      logging.info_with_context("Task started", "base_agent", [
        #("task_id", task_id),
        #("task_type", task_type),
        #("priority", types.priority_to_string(priority)),
      ])

      actor.continue(new_state)
    }
    False -> {
      logging.warn_with_context(
        "Task rejected - agent at capacity",
        "base_agent",
        [
          #("task_id", task_id),
          #("current_tasks", int_to_string(list.length(state.current_tasks))),
          #("max_tasks", int_to_string(state.config.max_concurrent_tasks)),
        ],
      )

      actor.continue(state)
    }
  }
}

/// Handle completing a task
fn handle_complete_task(
  task_id: String,
  success: Bool,
  state: AgentState,
) -> actor.Next(AgentState, AgentMessage) {
  let updated_tasks =
    list.filter(state.current_tasks, fn(task) { task.task_id != task_id })

  let updated_stats = case success {
    True ->
      AgentStatistics(
        ..state.statistics,
        tasks_completed: state.statistics.tasks_completed + 1,
      )
    False ->
      AgentStatistics(
        ..state.statistics,
        tasks_failed: state.statistics.tasks_failed + 1,
      )
  }

  let new_state =
    AgentState(..state, current_tasks: updated_tasks, statistics: updated_stats)

  logging.info_with_context("Task completed", "base_agent", [
    #("task_id", task_id),
    #("success", bool_to_string(success)),
    #("remaining_tasks", int_to_string(list.length(updated_tasks))),
  ])

  actor.continue(new_state)
}

/// Handle status update
fn handle_update_status(
  new_status: ServiceStatus,
  state: AgentState,
) -> actor.Next(AgentState, AgentMessage) {
  let old_status = state.status
  let new_state = AgentState(..state, status: new_status)

  logging.info_with_context("Agent status updated", "base_agent", [
    #("old_status", types.service_status_to_string(old_status)),
    #("new_status", types.service_status_to_string(new_status)),
  ])

  actor.continue(new_state)
}

/// Handle health check
fn handle_health_check(
  state: AgentState,
) -> actor.Next(AgentState, AgentMessage) {
  let health_status = calculate_health_status(state)
  let new_state = AgentState(..state, health: health_status)

  logging.debug_with_context("Health check performed", "base_agent", [
    #("health", types.health_status_to_string(health_status)),
    #("active_tasks", int_to_string(list.length(state.current_tasks))),
  ])

  actor.continue(new_state)
}

/// Handle status request
fn handle_get_status(state: AgentState) -> actor.Next(AgentState, AgentMessage) {
  logging.debug_with_context("Status requested", "base_agent", [
    #("status", types.service_status_to_string(state.status)),
    #("health", types.health_status_to_string(state.health)),
  ])

  actor.continue(state)
}

/// Handle statistics request
fn handle_get_statistics(
  state: AgentState,
) -> actor.Next(AgentState, AgentMessage) {
  logging.debug_with_context("Statistics requested", "base_agent", [
    #("completed", int_to_string(state.statistics.tasks_completed)),
    #("failed", int_to_string(state.statistics.tasks_failed)),
  ])

  actor.continue(state)
}

/// Handle heartbeat
fn handle_heartbeat(state: AgentState) -> actor.Next(AgentState, AgentMessage) {
  let new_state = AgentState(..state, last_heartbeat: types.now())

  logging.debug_with_context("Heartbeat sent", "base_agent", [
    #("agent_id", types.agent_id_to_string(state.config.id)),
  ])

  actor.continue(new_state)
}

/// Handle shutdown
fn handle_shutdown(state: AgentState) -> actor.Next(AgentState, AgentMessage) {
  logging.info_with_context("Agent shutting down", "base_agent", [
    #("agent_id", types.agent_id_to_string(state.config.id)),
    #("pending_tasks", int_to_string(list.length(state.current_tasks))),
  ])

  actor.stop()
}

/// Check if the agent can accept a new task
fn can_accept_task(state: AgentState) -> Bool {
  case state.status {
    types.Running -> {
      list.length(state.current_tasks) < state.config.max_concurrent_tasks
    }
    _ -> False
  }
}

/// Calculate current health status based on agent state
fn calculate_health_status(state: AgentState) -> HealthStatus {
  case state.status {
    types.Running -> {
      let task_load = list.length(state.current_tasks)
      let max_tasks = state.config.max_concurrent_tasks
      let load_ratio = case max_tasks {
        0 -> 0
        _ -> { task_load * 100 } / max_tasks
      }

      case load_ratio {
        ratio if ratio >= 90 -> types.Degraded
        _ -> types.Healthy
      }
    }
    types.Starting -> types.Unknown
    types.Stopping -> types.Degraded
    types.Error -> types.Failed
    _ -> types.Unknown
  }
}

/// Utility functions
fn int_to_string(value: Int) -> String {
  case value {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    _ -> "many"
  }
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

/// Public API functions for interacting with agents
/// Send a message to start a task
pub fn start_task(
  agent: actor.Started(process.Subject(AgentMessage)),
  task_id: String,
  task_type: String,
  priority: types.Priority,
) -> Nil {
  process.send(agent.data, StartTask(task_id, task_type, priority))
}

/// Send a message to complete a task
pub fn complete_task(
  agent: actor.Started(process.Subject(AgentMessage)),
  task_id: String,
  success: Bool,
) -> Nil {
  process.send(agent.data, CompleteTask(task_id, success))
}

/// Send a health check message
pub fn health_check(agent: actor.Started(process.Subject(AgentMessage))) -> Nil {
  process.send(agent.data, HealthCheck)
}

/// Send a heartbeat message
pub fn heartbeat(agent: actor.Started(process.Subject(AgentMessage))) -> Nil {
  process.send(agent.data, Heartbeat)
}

/// Send a shutdown message
pub fn shutdown(agent: actor.Started(process.Subject(AgentMessage))) -> Nil {
  process.send(agent.data, Shutdown)
}
