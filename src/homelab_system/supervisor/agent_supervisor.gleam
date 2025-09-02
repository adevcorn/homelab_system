/// Agent supervisor for managing agent processes in the homelab system
/// Handles supervision of base agents and specialized agent types
import gleam/erlang/process
import gleam/list
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/otp/static_supervisor.{type Supervisor} as supervisor
import gleam/otp/supervision

import homelab_system/agent/base_agent
import homelab_system/config/node_config.{type NodeConfig}
import homelab_system/utils/logging

/// Agent supervisor state
pub type AgentSupervisorState {
  AgentSupervisorState(
    config: NodeConfig,
    agents: List(AgentInfo),
    status: SupervisorStatus,
    restart_policy: RestartPolicy,
  )
}

/// Information about managed agents
pub type AgentInfo {
  AgentInfo(
    agent_id: String,
    agent_type: String,
    pid: Option(process.Pid),
    status: AgentStatus,
    restart_count: Int,
  )
}

/// Agent supervisor status
pub type SupervisorStatus {
  SupervisorStarting
  SupervisorRunning
  SupervisorStopping
  SupervisorStopped
  SupervisorFailed
}

/// Individual agent status
pub type AgentStatus {
  AgentStarting
  AgentRunning
  AgentStopping
  AgentStopped
  AgentFailed
}

/// Restart policy for agents
pub type RestartPolicy {
  RestartOneForOne
  // Restart only the failed agent
  RestartOneForAll
  // Restart all agents if one fails
  RestartRestForOne
  // Restart failed agent and all agents started after it
}

/// Start the agent supervisor
pub fn start_link(
  config: NodeConfig,
) -> Result(actor.Started(Supervisor), actor.StartError) {
  logging.info("Starting agent supervisor")

  let agent_supervisor_spec = create_agent_supervisor_spec(config)

  case agent_supervisor_spec |> supervisor.start {
    Ok(started) -> {
      logging.info("Agent supervisor started successfully")
      Ok(started)
    }
    Error(error) -> {
      logging.error("Failed to start agent supervisor")
      Error(error)
    }
  }
}

/// Create supervisor specification for agents
fn create_agent_supervisor_spec(config: NodeConfig) -> supervisor.Builder {
  let strategy = determine_restart_strategy(config)

  supervisor.new(strategy)
  |> supervisor.add(create_base_agent_spec(config))
  |> add_specialized_agents(config)
}

/// Determine restart strategy based on node role
fn determine_restart_strategy(config: NodeConfig) -> supervisor.Strategy {
  case config.role {
    node_config.Coordinator -> supervisor.OneForAll
    node_config.Gateway -> supervisor.OneForOne
    node_config.Monitor -> supervisor.OneForOne
    node_config.Agent(_) -> supervisor.OneForOne
  }
}

/// Create base agent child specification
fn create_base_agent_spec(
  config: NodeConfig,
) -> supervision.ChildSpecification(process.Subject(base_agent.AgentMessage)) {
  logging.debug("Creating base agent specification")

  supervision.worker(fn() {
    logging.info("Starting base agent from agent supervisor")
    base_agent.start_link(config)
  })
}

/// Add specialized agents based on node configuration
fn add_specialized_agents(
  builder: supervisor.Builder,
  config: NodeConfig,
) -> supervisor.Builder {
  case config.role {
    node_config.Agent(agent_type) ->
      add_agent_type_specific_processes(builder, agent_type, config)

    node_config.Coordinator ->
      builder
      |> add_coordinator_agents(config)

    node_config.Gateway ->
      builder
      |> add_gateway_agents(config)

    node_config.Monitor ->
      builder
      |> add_monitoring_agents(config)
  }
}

/// Add agent type specific processes
fn add_agent_type_specific_processes(
  builder: supervisor.Builder,
  agent_type: node_config.AgentType,
  config: NodeConfig,
) -> supervisor.Builder {
  case agent_type {
    node_config.Monitoring ->
      builder
      |> add_monitoring_agent_processes(config)

    node_config.Storage ->
      builder
      |> add_storage_agent_processes(config)

    node_config.Compute ->
      builder
      |> add_compute_agent_processes(config)

    node_config.Network ->
      builder
      |> add_network_agent_processes(config)

    node_config.Generic -> builder
    // Base agent is sufficient for generic agents
  }
}

/// Add monitoring-specific agent processes
fn add_monitoring_agent_processes(
  builder: supervisor.Builder,
  _config: NodeConfig,
) -> supervisor.Builder {
  logging.debug("Adding monitoring agent processes")
  // TODO: Add monitoring-specific agents
  // - Metrics collector agent
  // - Health check agent
  // - Log aggregation agent
  builder
}

/// Add storage-specific agent processes
fn add_storage_agent_processes(
  builder: supervisor.Builder,
  _config: NodeConfig,
) -> supervisor.Builder {
  logging.debug("Adding storage agent processes")
  // TODO: Add storage-specific agents
  // - Backup agent
  // - Data integrity agent
  // - Storage monitoring agent
  builder
}

/// Add compute-specific agent processes
fn add_compute_agent_processes(
  builder: supervisor.Builder,
  _config: NodeConfig,
) -> supervisor.Builder {
  logging.debug("Adding compute agent processes")
  // TODO: Add compute-specific agents
  // - Task execution agent
  // - Resource monitoring agent
  // - Load balancing agent
  builder
}

/// Add network-specific agent processes
fn add_network_agent_processes(
  builder: supervisor.Builder,
  _config: NodeConfig,
) -> supervisor.Builder {
  logging.debug("Adding network agent processes")
  // TODO: Add network-specific agents
  // - Network monitoring agent
  // - Connectivity check agent
  // - Bandwidth monitoring agent
  builder
}

/// Add coordinator-specific agents
fn add_coordinator_agents(
  builder: supervisor.Builder,
  _config: NodeConfig,
) -> supervisor.Builder {
  logging.debug("Adding coordinator agents")
  // TODO: Add coordinator-specific agents
  // - Cluster coordination agent
  // - Leader election agent
  // - Resource allocation agent
  builder
}

/// Add gateway-specific agents
fn add_gateway_agents(
  builder: supervisor.Builder,
  _config: NodeConfig,
) -> supervisor.Builder {
  logging.debug("Adding gateway agents")
  // TODO: Add gateway-specific agents
  // - API gateway agent
  // - Load balancer agent
  // - Authentication agent
  builder
}

/// Add monitoring node agents
fn add_monitoring_agents(
  builder: supervisor.Builder,
  _config: NodeConfig,
) -> supervisor.Builder {
  logging.debug("Adding monitoring node agents")
  // TODO: Add monitoring node agents
  // - System metrics agent
  // - Alert management agent
  // - Dashboard agent
  builder
}

/// Get agent supervisor status
pub fn get_status() -> Result(SupervisorStatus, String) {
  logging.debug("Getting agent supervisor status")
  // TODO: Implement actual status retrieval
  Ok(SupervisorRunning)
}

/// Get information about all managed agents
pub fn get_agents() -> Result(List(AgentInfo), String) {
  logging.debug("Getting agent information")
  // TODO: Implement actual agent info retrieval
  Ok([])
}

/// Restart a specific agent by ID
pub fn restart_agent(agent_id: String) -> Result(Nil, String) {
  logging.info("Restarting agent: " <> agent_id)

  case validate_agent_id(agent_id) {
    Ok(_) -> {
      case stop_agent(agent_id) {
        Ok(_) -> {
          case start_agent(agent_id) {
            Ok(_) -> {
              logging.info("Agent restarted successfully: " <> agent_id)
              Ok(Nil)
            }
            Error(reason) -> {
              logging.error("Failed to start agent: " <> reason)
              Error("Start failed: " <> reason)
            }
          }
        }
        Error(reason) -> {
          logging.error("Failed to stop agent: " <> reason)
          Error("Stop failed: " <> reason)
        }
      }
    }
    Error(reason) -> {
      logging.error("Invalid agent ID: " <> reason)
      Error("Invalid agent: " <> reason)
    }
  }
}

/// Stop a specific agent
pub fn stop_agent(agent_id: String) -> Result(Nil, String) {
  logging.info("Stopping agent: " <> agent_id)
  // TODO: Implement agent stop logic
  Ok(Nil)
}

/// Start a specific agent
pub fn start_agent(agent_id: String) -> Result(Nil, String) {
  logging.info("Starting agent: " <> agent_id)
  // TODO: Implement agent start logic
  Ok(Nil)
}

/// Validate agent ID
fn validate_agent_id(_agent_id: String) -> Result(Nil, String) {
  // TODO: Implement agent ID validation
  Ok(Nil)
}

/// Shutdown agent supervisor gracefully
pub fn shutdown() -> Result(Nil, String) {
  logging.info("Shutting down agent supervisor")

  case shutdown_all_agents() {
    Ok(_) -> {
      logging.info("All agents shut down successfully")
      Ok(Nil)
    }
    Error(reason) -> {
      logging.error("Error shutting down agents: " <> reason)
      Error("Shutdown failed: " <> reason)
    }
  }
}

/// Shutdown all managed agents
fn shutdown_all_agents() -> Result(Nil, String) {
  logging.debug("Shutting down all agents")
  // TODO: Implement ordered agent shutdown
  // Should stop agents in reverse dependency order
  Ok(Nil)
}

/// Get agent supervisor statistics
pub fn get_statistics() -> Result(AgentSupervisorStatistics, String) {
  logging.debug("Getting agent supervisor statistics")
  // TODO: Implement statistics gathering
  Ok(AgentSupervisorStatistics(
    total_agents: 0,
    running_agents: 0,
    failed_agents: 0,
    total_restarts: 0,
    uptime_seconds: 0,
  ))
}

/// Agent supervisor statistics
pub type AgentSupervisorStatistics {
  AgentSupervisorStatistics(
    total_agents: Int,
    running_agents: Int,
    failed_agents: Int,
    total_restarts: Int,
    uptime_seconds: Int,
  )
}

/// Health check for agent supervisor
pub fn health_check() -> Result(Bool, String) {
  logging.debug("Performing agent supervisor health check")

  case get_status() {
    Ok(SupervisorRunning) -> {
      case get_agents() {
        Ok(agents) -> {
          let healthy_agents =
            list.filter(agents, fn(agent) {
              case agent.status {
                AgentRunning -> True
                _ -> False
              }
            })

          // Consider healthy if at least one agent is running
          Ok(list.length(healthy_agents) > 0)
        }
        Error(reason) -> Error("Failed to check agents: " <> reason)
      }
    }
    Ok(_) -> Ok(False)
    Error(reason) -> Error("Status check failed: " <> reason)
  }
}

/// Create a supervised version for use in larger supervision trees
pub fn supervised(
  config: NodeConfig,
) -> supervision.ChildSpecification(Supervisor) {
  logging.debug("Creating supervised agent supervisor specification")
  create_agent_supervisor_spec(config)
  |> supervisor.supervised
}
