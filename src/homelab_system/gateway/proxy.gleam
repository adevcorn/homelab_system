//// Homelab System Gateway Proxy Module
////
//// This module provides gateway functionality for handling external communication
//// and proxying requests between internal services and external clients.
////
//// Features:
//// - Request proxying and load balancing
//// - External API gateway functionality
//// - Service discovery integration
//// - Request routing and filtering
//// - Authentication and authorization

import gleam/dict.{type Dict}
import gleam/http.{type Method}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/list
import gleam/result
import gleam/string

/// Gateway configuration
pub type GatewayConfig {
  GatewayConfig(
    host: String,
    port: Int,
    enabled: Bool,
    routes: Dict(String, RouteConfig),
  )
}

/// Route configuration
pub type RouteConfig {
  RouteConfig(
    path: String,
    target_host: String,
    target_port: Int,
    methods: List(Method),
    auth_required: Bool,
  )
}

/// Gateway state
pub type GatewayState {
  GatewayState(
    config: GatewayConfig,
    active: Bool,
    request_count: Int,
    error_count: Int,
  )
}

/// Proxy result
pub type ProxyResult {
  ProxySuccess(response: Response(String))
  ProxyError(message: String, code: Int)
}

/// Create a new gateway configuration
pub fn new_config() -> GatewayConfig {
  GatewayConfig(host: "0.0.0.0", port: 8080, enabled: True, routes: dict.new())
}

/// Create a new gateway state
pub fn new_state(config: GatewayConfig) -> GatewayState {
  GatewayState(config: config, active: False, request_count: 0, error_count: 0)
}

/// Start the gateway
pub fn start(state: GatewayState) -> Result(GatewayState, String) {
  case state.config.enabled {
    True -> {
      // TODO: Implement actual gateway startup logic
      Ok(GatewayState(..state, active: True))
    }
    False -> Error("Gateway is disabled")
  }
}

/// Stop the gateway
pub fn stop(state: GatewayState) -> GatewayState {
  GatewayState(..state, active: False)
}

/// Add a route to the gateway
pub fn add_route(
  state: GatewayState,
  route_name: String,
  route_config: RouteConfig,
) -> GatewayState {
  let updated_routes =
    dict.insert(state.config.routes, route_name, route_config)
  let updated_config = GatewayConfig(..state.config, routes: updated_routes)
  GatewayState(..state, config: updated_config)
}

/// Remove a route from the gateway
pub fn remove_route(state: GatewayState, route_name: String) -> GatewayState {
  let updated_routes = dict.delete(state.config.routes, route_name)
  let updated_config = GatewayConfig(..state.config, routes: updated_routes)
  GatewayState(..state, config: updated_config)
}

/// Handle incoming request and proxy to appropriate service
pub fn handle_request(
  state: GatewayState,
  req: Request(String),
) -> #(GatewayState, ProxyResult) {
  case state.active {
    False -> {
      let error = ProxyError("Gateway is not active", 503)
      #(state, error)
    }
    True -> {
      let path = req.path
      let method = req.method

      case find_matching_route(state.config.routes, path, method) {
        Ok(route_config) -> {
          let result = proxy_request(req, route_config)
          let updated_state =
            GatewayState(..state, request_count: state.request_count + 1)
          #(updated_state, result)
        }
        Error(_) -> {
          let error = ProxyError("No route found for path: " <> path, 404)
          let updated_state =
            GatewayState(
              ..state,
              request_count: state.request_count + 1,
              error_count: state.error_count + 1,
            )
          #(updated_state, error)
        }
      }
    }
  }
}

/// Find a matching route for the given path and method
fn find_matching_route(
  routes: Dict(String, RouteConfig),
  path: String,
  method: Method,
) -> Result(RouteConfig, String) {
  let route_pairs = dict.to_list(routes)

  case
    list.find(route_pairs, fn(pair) {
      let #(_name, route_config) = pair
      path_matches(route_config.path, path)
      && list.contains(route_config.methods, method)
    })
  {
    Ok(#(_name, route_config)) -> Ok(route_config)
    Error(_) -> Error("No matching route found")
  }
}

/// Check if a route path matches the request path
fn path_matches(route_path: String, request_path: String) -> Bool {
  // Simple prefix matching for now
  // TODO: Implement more sophisticated path matching with wildcards
  string.starts_with(request_path, route_path)
}

/// Proxy the request to the target service
fn proxy_request(req: Request(String), route_config: RouteConfig) -> ProxyResult {
  // TODO: Implement actual HTTP proxying logic
  // For now, return a placeholder response

  case route_config.auth_required {
    True -> {
      case authenticate_request(req) {
        Ok(_) -> forward_request(req, route_config)
        Error(auth_error) ->
          ProxyError("Authentication failed: " <> auth_error, 401)
      }
    }
    False -> forward_request(req, route_config)
  }
}

/// Authenticate the request
fn authenticate_request(req: Request(String)) -> Result(Nil, String) {
  // TODO: Implement authentication logic
  // Check for API keys, JWT tokens, etc.
  Ok(Nil)
}

/// Forward the request to the target service
fn forward_request(
  req: Request(String),
  route_config: RouteConfig,
) -> ProxyResult {
  // TODO: Implement actual HTTP client request to target service
  let target_url =
    "http://"
    <> route_config.target_host
    <> ":"
    <> int_to_string(route_config.target_port)

  // Placeholder response
  let response =
    response.new(200)
    |> response.set_body(
      "{\"message\":\"Proxied request (placeholder)\",\"target\":\""
      <> target_url
      <> "\"}",
    )
    |> response.set_header("content-type", "application/json")

  ProxySuccess(response)
}

/// Helper function to convert int to string
fn int_to_string(value: Int) -> String {
  int.to_string(value)
}

/// Get gateway statistics
pub fn get_stats(state: GatewayState) -> Dict(String, Int) {
  dict.new()
  |> dict.insert("request_count", state.request_count)
  |> dict.insert("error_count", state.error_count)
  |> dict.insert("active_routes", dict.size(state.config.routes))
}

/// Check if gateway is active
pub fn is_active(state: GatewayState) -> Bool {
  state.active
}

/// Get configured routes
pub fn get_routes(state: GatewayState) -> Dict(String, RouteConfig) {
  state.config.routes
}

// Predefined route configurations for common services

/// Create a route configuration for the API service
pub fn api_route_config() -> RouteConfig {
  RouteConfig(
    path: "/api",
    target_host: "127.0.0.1",
    target_port: 8081,
    methods: [http.Get, http.Post, http.Put, http.Delete],
    auth_required: True,
  )
}

/// Create a route configuration for the health check service
pub fn health_route_config() -> RouteConfig {
  RouteConfig(
    path: "/health",
    target_host: "127.0.0.1",
    target_port: 8082,
    methods: [http.Get],
    auth_required: False,
  )
}

/// Create a route configuration for metrics service
pub fn metrics_route_config() -> RouteConfig {
  RouteConfig(
    path: "/metrics",
    target_host: "127.0.0.1",
    target_port: 8083,
    methods: [http.Get],
    auth_required: True,
  )
}

/// Setup default routes for the gateway
pub fn setup_default_routes(state: GatewayState) -> GatewayState {
  state
  |> add_route("api", api_route_config())
  |> add_route("health", health_route_config())
  |> add_route("metrics", metrics_route_config())
}
