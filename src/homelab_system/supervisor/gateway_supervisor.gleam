/// Gateway supervisor for managing external interfaces in the homelab system
/// Handles supervision of API gateways, web interfaces, and external communication services
import gleam/erlang/process
import gleam/list
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/otp/static_supervisor.{type Supervisor} as supervisor
import gleam/otp/supervision

import homelab_system/config/node_config.{type NodeConfig}
import homelab_system/utils/logging

/// Gateway supervisor state
pub type GatewaySupervisorState {
  GatewaySupervisorState(
    config: NodeConfig,
    gateways: List(GatewayInfo),
    status: GatewaySupervisorStatus,
    load_balancer_state: LoadBalancerState,
  )
}

/// Information about gateway services
pub type GatewayInfo {
  GatewayInfo(
    gateway_id: String,
    gateway_type: GatewayType,
    pid: Option(process.Pid),
    status: GatewayStatus,
    restart_count: Int,
    endpoint: String,
    active_connections: Int,
  )
}

/// Types of gateway services
pub type GatewayType {
  HttpGateway
  ApiGateway
  WebSocketGateway
  LoadBalancer
  ReverseProxy
  AuthenticationGateway
}

/// Gateway supervisor status
pub type GatewaySupervisorStatus {
  GatewayStarting
  GatewayRunning
  GatewayStopping
  GatewayStopped
  GatewayFailed
  GatewayOverloaded
}

/// Individual gateway status
pub type GatewayStatus {
  GatewayServiceStarting
  GatewayServiceRunning
  GatewayServiceStopping
  GatewayServiceStopped
  GatewayServiceFailed
  GatewayServiceOverloaded
}

/// Load balancer state
pub type LoadBalancerState {
  LoadBalancerState(
    algorithm: LoadBalanceAlgorithm,
    backend_nodes: List(String),
    health_check_enabled: Bool,
  )
}

/// Load balancing algorithms
pub type LoadBalanceAlgorithm {
  RoundRobin
  LeastConnections
  WeightedRoundRobin
  IpHash
}

/// Start the gateway supervisor
pub fn start_link(
  config: NodeConfig,
) -> Result(actor.Started(Supervisor), actor.StartError) {
  logging.info("Starting gateway supervisor")

  let gateway_supervisor_spec = create_gateway_supervisor_spec(config)

  case gateway_supervisor_spec |> supervisor.start {
    Ok(started) -> {
      logging.info("Gateway supervisor started successfully")
      Ok(started)
    }
    Error(error) -> {
      logging.error("Failed to start gateway supervisor")
      Error(error)
    }
  }
}

/// Create supervisor specification for gateway services
fn create_gateway_supervisor_spec(config: NodeConfig) -> supervisor.Builder {
  supervisor.new(supervisor.OneForOne)
  |> add_http_gateway(config)
  |> add_api_gateway(config)
  |> add_websocket_gateway(config)
  |> add_authentication_gateway(config)
  |> add_load_balancer(config)
}

/// Add HTTP gateway service
fn add_http_gateway(
  builder: supervisor.Builder,
  config: NodeConfig,
) -> supervisor.Builder {
  case config.features.web_interface {
    True -> {
      logging.debug("Adding HTTP gateway service")
      // TODO: Add HTTP gateway child spec
      // - Static file serving
      // - HTTP request routing
      // - HTTPS/TLS support
      builder
    }
    False -> {
      logging.debug("Skipping HTTP gateway (web interface disabled)")
      builder
    }
  }
}

/// Add API gateway service
fn add_api_gateway(
  builder: supervisor.Builder,
  config: NodeConfig,
) -> supervisor.Builder {
  case config.features.api_endpoints {
    True -> {
      logging.debug("Adding API gateway service")
      // TODO: Add API gateway child spec
      // - REST API routing
      // - API versioning
      // - Rate limiting
      // - Request/response transformation
      builder
    }
    False -> {
      logging.debug("Skipping API gateway (API endpoints disabled)")
      builder
    }
  }
}

/// Add WebSocket gateway service
fn add_websocket_gateway(
  builder: supervisor.Builder,
  config: NodeConfig,
) -> supervisor.Builder {
  case config.features.web_interface {
    True -> {
      logging.debug("Adding WebSocket gateway service")
      // TODO: Add WebSocket gateway child spec
      // - Real-time communication
      // - Connection management
      // - Message broadcasting
      builder
    }
    False -> {
      logging.debug("Skipping WebSocket gateway (web interface disabled)")
      builder
    }
  }
}

/// Add authentication gateway service
fn add_authentication_gateway(
  builder: supervisor.Builder,
  _config: NodeConfig,
) -> supervisor.Builder {
  logging.debug("Adding authentication gateway service")
  // TODO: Add authentication gateway child spec
  // - User authentication
  // - Token validation
  // - Session management
  // - OAuth/OIDC support
  builder
}

/// Add load balancer service
fn add_load_balancer(
  builder: supervisor.Builder,
  config: NodeConfig,
) -> supervisor.Builder {
  case config.features.load_balancing {
    True -> {
      logging.debug("Adding load balancer service")
      // TODO: Add load balancer child spec
      // - Request distribution
      // - Health checking
      // - Failover handling
      builder
    }
    False -> {
      logging.debug("Skipping load balancer (load balancing disabled)")
      builder
    }
  }
}

/// Get gateway supervisor status
pub fn get_status() -> Result(GatewaySupervisorStatus, String) {
  logging.debug("Getting gateway supervisor status")
  // TODO: Implement actual status retrieval
  Ok(GatewayRunning)
}

/// Get information about all gateway services
pub fn get_gateways() -> Result(List(GatewayInfo), String) {
  logging.debug("Getting gateway services information")
  // TODO: Implement actual gateway info retrieval
  Ok([])
}

/// Get current load balancer state
pub fn get_load_balancer_state() -> Result(LoadBalancerState, String) {
  logging.debug("Getting load balancer state")
  // TODO: Implement load balancer state retrieval
  Ok(LoadBalancerState(
    algorithm: RoundRobin,
    backend_nodes: [],
    health_check_enabled: True,
  ))
}

/// Add backend node to load balancer
pub fn add_backend_node(node_endpoint: String) -> Result(Nil, String) {
  logging.info("Adding backend node: " <> node_endpoint)

  case validate_endpoint(node_endpoint) {
    Ok(_) -> {
      case register_backend(node_endpoint) {
        Ok(_) -> {
          logging.info("Backend node added successfully: " <> node_endpoint)
          Ok(Nil)
        }
        Error(reason) -> {
          logging.error("Failed to register backend: " <> reason)
          Error("Registration failed: " <> reason)
        }
      }
    }
    Error(reason) -> {
      logging.error("Invalid endpoint: " <> reason)
      Error("Invalid endpoint: " <> reason)
    }
  }
}

/// Remove backend node from load balancer
pub fn remove_backend_node(node_endpoint: String) -> Result(Nil, String) {
  logging.info("Removing backend node: " <> node_endpoint)

  case unregister_backend(node_endpoint) {
    Ok(_) -> {
      logging.info("Backend node removed successfully: " <> node_endpoint)
      Ok(Nil)
    }
    Error(reason) -> {
      logging.error("Failed to unregister backend: " <> reason)
      Error("Unregistration failed: " <> reason)
    }
  }
}

/// Update load balancer algorithm
pub fn set_load_balance_algorithm(
  _algorithm: LoadBalanceAlgorithm,
) -> Result(Nil, String) {
  logging.info("Updating load balancer algorithm")
  // TODO: Implement algorithm update
  Ok(Nil)
}

/// Restart a specific gateway service
pub fn restart_gateway(gateway_id: String) -> Result(Nil, String) {
  logging.info("Restarting gateway service: " <> gateway_id)

  case validate_gateway_id(gateway_id) {
    Ok(_) -> {
      case stop_gateway(gateway_id) {
        Ok(_) -> {
          case start_gateway(gateway_id) {
            Ok(_) -> {
              logging.info("Gateway restarted successfully: " <> gateway_id)
              Ok(Nil)
            }
            Error(reason) -> {
              logging.error("Failed to start gateway: " <> reason)
              Error("Start failed: " <> reason)
            }
          }
        }
        Error(reason) -> {
          logging.error("Failed to stop gateway: " <> reason)
          Error("Stop failed: " <> reason)
        }
      }
    }
    Error(reason) -> {
      logging.error("Invalid gateway ID: " <> reason)
      Error("Invalid gateway: " <> reason)
    }
  }
}

/// Stop a specific gateway service
fn stop_gateway(gateway_id: String) -> Result(Nil, String) {
  logging.info("Stopping gateway service: " <> gateway_id)
  // TODO: Implement gateway stop logic
  Ok(Nil)
}

/// Start a specific gateway service
fn start_gateway(gateway_id: String) -> Result(Nil, String) {
  logging.info("Starting gateway service: " <> gateway_id)
  // TODO: Implement gateway start logic
  Ok(Nil)
}

/// Validate gateway ID
fn validate_gateway_id(_gateway_id: String) -> Result(Nil, String) {
  // TODO: Implement gateway ID validation
  Ok(Nil)
}

/// Validate endpoint format
fn validate_endpoint(_endpoint: String) -> Result(Nil, String) {
  // TODO: Implement endpoint validation
  // Check URL format, reachability, etc.
  Ok(Nil)
}

/// Register backend node
fn register_backend(_endpoint: String) -> Result(Nil, String) {
  // TODO: Implement backend registration
  Ok(Nil)
}

/// Unregister backend node
fn unregister_backend(_endpoint: String) -> Result(Nil, String) {
  // TODO: Implement backend unregistration
  Ok(Nil)
}

/// Get gateway connection statistics
pub fn get_connection_stats() -> Result(GatewayConnectionStats, String) {
  logging.debug("Getting gateway connection statistics")
  // TODO: Implement connection stats retrieval
  Ok(GatewayConnectionStats(
    total_connections: 0,
    active_connections: 0,
    requests_per_second: 0,
    average_response_time_ms: 0,
    error_rate_percent: 0,
  ))
}

/// Gateway connection statistics
pub type GatewayConnectionStats {
  GatewayConnectionStats(
    total_connections: Int,
    active_connections: Int,
    requests_per_second: Int,
    average_response_time_ms: Int,
    error_rate_percent: Int,
  )
}

/// Shutdown gateway supervisor gracefully
pub fn shutdown() -> Result(Nil, String) {
  logging.info("Shutting down gateway supervisor")

  case drain_connections() {
    Ok(_) -> {
      case shutdown_all_gateways() {
        Ok(_) -> {
          logging.info("Gateway supervisor shut down successfully")
          Ok(Nil)
        }
        Error(reason) -> {
          logging.error("Error shutting down gateways: " <> reason)
          Error("Gateway shutdown failed: " <> reason)
        }
      }
    }
    Error(reason) -> {
      logging.error("Error draining connections: " <> reason)
      // Continue with shutdown even if drain failed
      case shutdown_all_gateways() {
        Ok(_) -> Ok(Nil)
        Error(shutdown_reason) ->
          Error("Multiple failures: " <> reason <> ", " <> shutdown_reason)
      }
    }
  }
}

/// Drain existing connections before shutdown
fn drain_connections() -> Result(Nil, String) {
  logging.debug("Draining existing connections")
  // TODO: Implement connection draining
  // - Stop accepting new connections
  // - Wait for existing connections to complete
  // - Force close after timeout
  Ok(Nil)
}

/// Shutdown all gateway services
fn shutdown_all_gateways() -> Result(Nil, String) {
  logging.debug("Shutting down all gateway services")
  // TODO: Implement ordered gateway shutdown
  Ok(Nil)
}

/// Get gateway supervisor statistics
pub fn get_statistics() -> Result(GatewaySupervisorStatistics, String) {
  logging.debug("Getting gateway supervisor statistics")
  // TODO: Implement statistics gathering
  Ok(GatewaySupervisorStatistics(
    total_gateways: 0,
    running_gateways: 0,
    failed_gateways: 0,
    total_connections: 0,
    requests_handled: 0,
    uptime_seconds: 0,
  ))
}

/// Gateway supervisor statistics
pub type GatewaySupervisorStatistics {
  GatewaySupervisorStatistics(
    total_gateways: Int,
    running_gateways: Int,
    failed_gateways: Int,
    total_connections: Int,
    requests_handled: Int,
    uptime_seconds: Int,
  )
}

/// Health check for gateway supervisor
pub fn health_check() -> Result(Bool, String) {
  logging.debug("Performing gateway supervisor health check")

  case get_status() {
    Ok(GatewayRunning) -> {
      case get_gateways() {
        Ok(gateways) -> {
          let healthy_gateways =
            list.filter(gateways, fn(gateway) {
              case gateway.status {
                GatewayServiceRunning -> True
                _ -> False
              }
            })

          // Consider healthy if at least one gateway is running
          Ok(list.length(healthy_gateways) > 0)
        }
        Error(reason) -> Error("Failed to check gateways: " <> reason)
      }
    }
    Ok(GatewayOverloaded) -> {
      // Overloaded state is still functional, just under stress
      Ok(True)
    }
    Ok(_) -> Ok(False)
    Error(reason) -> Error("Status check failed: " <> reason)
  }
}

/// Create a supervised version for use in larger supervision trees
pub fn supervised(
  config: NodeConfig,
) -> supervision.ChildSpecification(Supervisor) {
  logging.debug("Creating supervised gateway supervisor specification")
  create_gateway_supervisor_spec(config)
  |> supervisor.supervised
}

/// Enable/disable rate limiting
pub fn set_rate_limiting(
  enabled: Bool,
  _requests_per_minute: Int,
) -> Result(Nil, String) {
  logging.info("Setting rate limiting: enabled=" <> bool_to_string(enabled))
  // TODO: Implement rate limiting configuration
  Ok(Nil)
}

/// Helper function to convert bool to string
fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

/// Get current rate limiting configuration
pub fn get_rate_limiting() -> Result(RateLimitConfig, String) {
  logging.debug("Getting rate limiting configuration")
  // TODO: Implement rate limit config retrieval
  Ok(RateLimitConfig(enabled: False, requests_per_minute: 0, burst_size: 0))
}

/// Rate limiting configuration
pub type RateLimitConfig {
  RateLimitConfig(enabled: Bool, requests_per_minute: Int, burst_size: Int)
}
