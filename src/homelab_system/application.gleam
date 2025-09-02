/// Main OTP application for the homelab system
/// Handles application startup, shutdown, and configuration loading
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/static_supervisor.{type Supervisor}
import gleam/string
import homelab_system/config/node_config.{type NodeConfig}
import homelab_system/supervisor
import homelab_system/utils/logging

/// Application state
pub type ApplicationState {
  ApplicationState(config: NodeConfig, supervisor: Supervisor, started_at: Int)
}

/// Application startup result
pub type StartResult {
  StartSuccess(state: ApplicationState)
  StartError(reason: String)
}

/// Start the homelab system application
/// This is the main entry point for the OTP application
pub fn start() -> StartResult {
  io.println("Starting Homelab System...")

  // Load configuration
  case load_configuration() {
    Ok(config) -> {
      io.println("Configuration loaded successfully")
      logging.info(
        "Starting homelab system with config: "
        <> node_config.get_config_summary(config),
      )

      // Start the main supervisor tree
      case supervisor.start_link(config) {
        Ok(sup) -> {
          let state =
            ApplicationState(
              config: config,
              supervisor: sup.data,
              started_at: get_current_timestamp(),
            )

          logging.info("Homelab system started successfully")
          print_startup_banner(config)
          StartSuccess(state)
        }
        Error(_reason) -> {
          let error_msg = "Failed to start supervisor"
          logging.error(error_msg)
          StartError(error_msg)
        }
      }
    }
    Error(error_msg) -> {
      logging.error("Configuration loading failed: " <> error_msg)
      StartError(error_msg)
    }
  }
}

/// Stop the homelab system application
pub fn stop(_state: ApplicationState) -> Result(Nil, String) {
  logging.info("Shutting down homelab system...")

  // Graceful shutdown sequence
  case supervisor.shutdown() {
    Ok(_) -> {
      logging.info("Homelab system shut down successfully")
      Ok(Nil)
    }
    Error(reason) -> {
      let error_msg = "Error during shutdown: " <> reason
      logging.error(error_msg)
      Error(error_msg)
    }
  }
}

/// Load node configuration from various sources
fn load_configuration() -> Result(NodeConfig, String) {
  // Load from environment
  let config = node_config.from_environment()

  // Validate the loaded configuration
  case node_config.validate_config(config) {
    Ok(_) -> Ok(config)
    Error(validation_errors) ->
      Error(
        "Configuration validation failed: "
        <> string_join(validation_errors, ", "),
      )
  }
}

/// Helper function to join strings with a separator
fn string_join(list: List(String), separator: String) -> String {
  string.join(list, separator)
}

/// Print a startup banner with system information
fn print_startup_banner(config: NodeConfig) -> Nil {
  io.println("╔════════════════════════════════════════╗")
  io.println("║           Homelab System               ║")
  io.println("║        Distributed Management         ║")
  io.println("╚════════════════════════════════════════╝")
  io.println("")
  io.println("Node ID:      " <> config.node_id)
  io.println("Node Name:    " <> config.node_name)
  io.println("Role:         " <> role_to_string(config.role))
  io.println("Environment:  " <> config.environment)
  io.println(
    "Bind Address: "
    <> config.network.bind_address
    <> ":"
    <> int.to_string(config.network.port),
  )

  case config.features.clustering {
    True -> io.println("Clustering:   Enabled")
    False -> io.println("Clustering:   Disabled")
  }

  case config.features.web_interface {
    True -> io.println("Web UI:       Enabled")
    False -> io.println("Web UI:       Disabled")
  }

  io.println("")
  io.println("System ready for connections...")
  io.println("")
}

/// Convert node role to display string
fn role_to_string(role: node_config.NodeRole) -> String {
  case role {
    node_config.Coordinator -> "Coordinator"
    node_config.Agent(agent_type) ->
      "Agent (" <> agent_type_to_string(agent_type) <> ")"
    node_config.Gateway -> "Gateway"
    node_config.Monitor -> "Monitor"
  }
}

/// Convert agent type to display string
fn agent_type_to_string(agent_type: node_config.AgentType) -> String {
  case agent_type {
    node_config.Monitoring -> "Monitoring"
    node_config.Storage -> "Storage"
    node_config.Compute -> "Compute"
    node_config.Network -> "Network"
    node_config.Generic -> "Generic"
  }
}

/// Get current timestamp (placeholder - would use actual time library)
fn get_current_timestamp() -> Int {
  // TODO: Implement actual timestamp using erlang time functions
  0
}

/// Convert integer to string
fn int_to_string(value: Int) -> String {
  int.to_string(value)
}

/// Get application runtime information
pub fn get_info(state: ApplicationState) -> String {
  "Homelab System - Node: "
  <> state.config.node_name
  <> ", Role: "
  <> role_to_string(state.config.role)
  <> ", Uptime: "
  <> int_to_string(get_current_timestamp() - state.started_at)
  <> "s"
}

/// Reload configuration without restarting
pub fn reload_config(
  state: ApplicationState,
) -> Result(ApplicationState, String) {
  case load_configuration() {
    Ok(new_config) -> {
      // TODO: Implement hot configuration reload
      logging.info("Configuration reloaded successfully")
      Ok(ApplicationState(..state, config: new_config))
    }
    Error(error_msg) -> {
      logging.error("Configuration reload failed: " <> error_msg)
      Error(error_msg)
    }
  }
}

/// Health check for the application
pub fn health_check(_state: ApplicationState) -> Bool {
  // TODO: Implement comprehensive health checks
  // - Check supervisor status
  // - Check critical services
  // - Check cluster connectivity
  // - Check resource usage
  True
}
