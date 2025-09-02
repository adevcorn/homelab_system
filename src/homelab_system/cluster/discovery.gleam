/// Service discovery mechanism for the homelab system
/// Manages service registration, discovery, and health checking across the cluster
import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/string

import homelab_system/utils/logging
import homelab_system/utils/types.{
  type HealthStatus, type NodeId, type ServiceId, type ServiceStatus,
  type SystemError, type Timestamp,
}

/// Service registry entry with metadata and health information
pub type ServiceEntry {
  ServiceEntry(
    id: ServiceId,
    name: String,
    version: String,
    node_id: NodeId,
    address: String,
    port: Int,
    health_endpoint: Option(String),
    health_status: HealthStatus,
    metadata: Dict(String, String),
    tags: List(String),
    registered_at: Timestamp,
    last_health_check: Timestamp,
    health_check_interval: Int,
    ttl: Option(Int),
  )
}

/// Service discovery query with filtering options
pub type ServiceQuery {
  ServiceQuery(
    name: Option(String),
    version: Option(String),
    tags: List(String),
    health_status: Option(HealthStatus),
    node_id: Option(NodeId),
    metadata_filters: Dict(String, String),
  )
}

/// Service discovery cache entry
pub type CacheEntry {
  CacheEntry(services: List(ServiceEntry), last_updated: Timestamp, ttl: Int)
}

/// Service discovery state
pub type ServiceDiscoveryState {
  ServiceDiscoveryState(
    local_registry: Dict(String, ServiceEntry),
    cache: Dict(String, CacheEntry),
    node_id: NodeId,
    cluster_name: String,
    health_check_interval: Int,
    cache_ttl: Int,
    registry_sync_interval: Int,
    status: ServiceStatus,
  )
}

/// Messages for the service discovery actor
pub type ServiceDiscoveryMessage {
  RegisterService(ServiceEntry)
  DeregisterService(ServiceId)
  UpdateService(ServiceEntry)
  DiscoverServices(ServiceQuery)
  HealthCheckService(ServiceId)
  HealthCheckAll
  SyncRegistry
  ClearCache
  GetRegistryStats
  Shutdown
}

/// Service discovery response types
pub type ServiceDiscoveryResponse {
  ServicesFound(List(ServiceEntry))
  ServiceRegistered(ServiceId)
  ServiceDeregistered(ServiceId)
  ServiceUpdated(ServiceId)
  HealthCheckCompleted(ServiceId, HealthStatus)
  RegistryStats(local_count: Int, cache_entries: Int)
  ErrorResponse(SystemError)
}

/// Start the service discovery actor
pub fn start_link(
  node_id: NodeId,
  cluster_name: String,
) -> Result(
  actor.Started(process.Subject(ServiceDiscoveryMessage)),
  actor.StartError,
) {
  let initial_state =
    ServiceDiscoveryState(
      local_registry: dict.new(),
      cache: dict.new(),
      node_id: node_id,
      cluster_name: cluster_name,
      health_check_interval: 30_000,
      // 30 seconds
      cache_ttl: 60_000,
      // 1 minute
      registry_sync_interval: 10_000,
      // 10 seconds
      status: types.Starting,
    )

  case
    actor.new(initial_state)
    |> actor.on_message(handle_message)
    |> actor.start
  {
    Ok(started) -> {
      logging.info(
        "Service discovery started for node: "
        <> types.node_id_to_string(node_id),
      )

      // Mark as running
      let updated_state =
        ServiceDiscoveryState(..initial_state, status: types.Running)
      // TODO: Update actor state properly
      let _ = updated_state
      Ok(started)
    }
    Error(err) -> {
      logging.error("Failed to start service discovery")
      Error(err)
    }
  }
}

/// Handle messages to the service discovery actor
fn handle_message(
  state: ServiceDiscoveryState,
  message: ServiceDiscoveryMessage,
) -> actor.Next(ServiceDiscoveryState, ServiceDiscoveryMessage) {
  case message {
    RegisterService(service_entry) ->
      handle_register_service(service_entry, state)
    DeregisterService(service_id) ->
      handle_deregister_service(service_id, state)
    UpdateService(service_entry) -> handle_update_service(service_entry, state)
    DiscoverServices(query) -> handle_discover_services(query, state)
    HealthCheckService(service_id) ->
      handle_health_check_service(service_id, state)
    HealthCheckAll -> handle_health_check_all(state)
    SyncRegistry -> handle_sync_registry(state)
    ClearCache -> handle_clear_cache(state)
    GetRegistryStats -> handle_get_registry_stats(state)
    Shutdown -> handle_shutdown(state)
  }
}

/// Handle service registration
fn handle_register_service(
  service_entry: ServiceEntry,
  state: ServiceDiscoveryState,
) -> actor.Next(ServiceDiscoveryState, ServiceDiscoveryMessage) {
  let service_key = types.service_id_to_string(service_entry.id)

  logging.info(
    "Registering service: " <> service_entry.name <> " (" <> service_key <> ")",
  )

  // Add to local registry
  let updated_local_registry =
    dict.insert(state.local_registry, service_key, service_entry)

  // Clear cache to force refresh
  let _cleared_cache = dict.new()

  let new_state =
    ServiceDiscoveryState(
      ..state,
      local_registry: updated_local_registry,
      cache: dict.new(),
    )

  logging.info("Service registered successfully: " <> service_entry.name)
  actor.continue(new_state)
}

/// Handle service deregistration
fn handle_deregister_service(
  service_id: ServiceId,
  state: ServiceDiscoveryState,
) -> actor.Next(ServiceDiscoveryState, ServiceDiscoveryMessage) {
  let service_key = types.service_id_to_string(service_id)

  logging.info("Deregistering service: " <> service_key)

  // Remove from local registry
  let updated_local_registry = dict.delete(state.local_registry, service_key)

  // Clear cache to force refresh
  let _cleared_cache = dict.new()

  let new_state =
    ServiceDiscoveryState(
      ..state,
      local_registry: updated_local_registry,
      cache: dict.new(),
    )

  logging.info("Service deregistered successfully: " <> service_key)
  actor.continue(new_state)
}

/// Handle service update
fn handle_update_service(
  service_entry: ServiceEntry,
  state: ServiceDiscoveryState,
) -> actor.Next(ServiceDiscoveryState, ServiceDiscoveryMessage) {
  let service_key = types.service_id_to_string(service_entry.id)

  logging.debug(
    "Updating service: " <> service_entry.name <> " (" <> service_key <> ")",
  )

  // Update local registry
  let updated_local_registry =
    dict.insert(state.local_registry, service_key, service_entry)

  // Clear cache to force refresh
  let _cleared_cache = dict.new()

  let new_state =
    ServiceDiscoveryState(
      ..state,
      local_registry: updated_local_registry,
      cache: dict.new(),
    )

  actor.continue(new_state)
}

/// Handle service discovery
fn handle_discover_services(
  query: ServiceQuery,
  state: ServiceDiscoveryState,
) -> actor.Next(ServiceDiscoveryState, ServiceDiscoveryMessage) {
  logging.debug("Discovering services with query")

  // Check cache first
  let cache_key = generate_cache_key(query)
  case dict.get(state.cache, cache_key) {
    Ok(cache_entry) -> {
      case is_cache_valid(cache_entry) {
        True -> {
          logging.debug("Returning cached service discovery results")
          actor.continue(state)
        }
        False -> perform_service_discovery(query, state, cache_key)
      }
    }
    Error(_) -> perform_service_discovery(query, state, cache_key)
  }
}

/// Perform actual service discovery
fn perform_service_discovery(
  query: ServiceQuery,
  state: ServiceDiscoveryState,
  cache_key: String,
) -> actor.Next(ServiceDiscoveryState, ServiceDiscoveryMessage) {
  // Gather services from local registry
  let local_services =
    get_services_from_local_registry(query, state.local_registry)

  // Filter services based on query
  let filtered_services = filter_services(local_services, query)

  // Cache the results
  let cache_entry =
    CacheEntry(
      services: filtered_services,
      last_updated: types.now(),
      ttl: state.cache_ttl,
    )

  let updated_cache = dict.insert(state.cache, cache_key, cache_entry)

  let new_state = ServiceDiscoveryState(..state, cache: updated_cache)

  logging.debug(
    "Service discovery completed, found "
    <> int.to_string(list.length(filtered_services))
    <> " services",
  )
  actor.continue(new_state)
}

/// Handle health check for a specific service
fn handle_health_check_service(
  service_id: ServiceId,
  state: ServiceDiscoveryState,
) -> actor.Next(ServiceDiscoveryState, ServiceDiscoveryMessage) {
  let service_key = types.service_id_to_string(service_id)

  case dict.get(state.local_registry, service_key) {
    Ok(service_entry) -> {
      logging.debug(
        "Performing health check for service: " <> service_entry.name,
      )

      let health_status = perform_health_check(service_entry)
      let updated_entry =
        ServiceEntry(
          ..service_entry,
          health_status: health_status,
          last_health_check: types.now(),
        )

      let updated_local_registry =
        dict.insert(state.local_registry, service_key, updated_entry)

      let new_state =
        ServiceDiscoveryState(
          ..state,
          local_registry: updated_local_registry,
          cache: dict.new(),
          // Clear cache
        )

      actor.continue(new_state)
    }
    Error(_) -> {
      logging.warn("Service not found for health check: " <> service_key)
      actor.continue(state)
    }
  }
}

/// Handle health check for all services
fn handle_health_check_all(
  state: ServiceDiscoveryState,
) -> actor.Next(ServiceDiscoveryState, ServiceDiscoveryMessage) {
  logging.debug("Performing health check for all services")

  let updated_registry =
    dict.map_values(state.local_registry, fn(_key, service_entry) {
      let health_status = perform_health_check(service_entry)
      ServiceEntry(
        ..service_entry,
        health_status: health_status,
        last_health_check: types.now(),
      )
    })

  let new_state =
    ServiceDiscoveryState(
      ..state,
      local_registry: updated_registry,
      cache: dict.new(),
      // Clear cache
    )

  logging.debug("Health check completed for all services")
  actor.continue(new_state)
}

/// Handle registry synchronization (placeholder for distributed sync)
fn handle_sync_registry(
  state: ServiceDiscoveryState,
) -> actor.Next(ServiceDiscoveryState, ServiceDiscoveryMessage) {
  logging.debug("Synchronizing service registry")

  // TODO: Implement distributed registry synchronization
  // For now, this is a no-op as we only have local registry

  logging.debug("Registry synchronization completed (local only)")
  actor.continue(state)
}

/// Handle cache clearing
fn handle_clear_cache(
  state: ServiceDiscoveryState,
) -> actor.Next(ServiceDiscoveryState, ServiceDiscoveryMessage) {
  logging.debug("Clearing service discovery cache")

  let new_state = ServiceDiscoveryState(..state, cache: dict.new())
  actor.continue(new_state)
}

/// Handle registry statistics request
fn handle_get_registry_stats(
  state: ServiceDiscoveryState,
) -> actor.Next(ServiceDiscoveryState, ServiceDiscoveryMessage) {
  let local_count = dict.size(state.local_registry)
  let cache_entries = dict.size(state.cache)

  logging.debug(
    "Registry stats - Local: "
    <> int.to_string(local_count)
    <> ", Cache: "
    <> int.to_string(cache_entries),
  )

  actor.continue(state)
}

/// Handle shutdown
fn handle_shutdown(
  _state: ServiceDiscoveryState,
) -> actor.Next(ServiceDiscoveryState, ServiceDiscoveryMessage) {
  logging.info("Shutting down service discovery")

  // Cleanup is minimal for local-only registry
  actor.stop()
}

/// Helper functions
/// Generate cache key from service query
fn generate_cache_key(query: ServiceQuery) -> String {
  let name_key = case query.name {
    Some(name) -> "name:" <> name
    None -> "name:*"
  }

  let version_key = case query.version {
    Some(version) -> "version:" <> version
    None -> "version:*"
  }

  let tags_key = "tags:" <> string.join(query.tags, ",")

  let health_key = case query.health_status {
    Some(health) -> "health:" <> types.health_status_to_string(health)
    None -> "health:*"
  }

  name_key <> "|" <> version_key <> "|" <> tags_key <> "|" <> health_key
}

/// Check if cache entry is still valid
fn is_cache_valid(cache_entry: CacheEntry) -> Bool {
  let current_time = types.now()
  let elapsed = case current_time, cache_entry.last_updated {
    types.Timestamp(current), types.Timestamp(last) -> current - last
  }
  elapsed < cache_entry.ttl
}

/// Get services from local registry based on query
fn get_services_from_local_registry(
  _query: ServiceQuery,
  local_registry: Dict(String, ServiceEntry),
) -> List(ServiceEntry) {
  dict.values(local_registry)
}

/// Filter services based on query criteria
fn filter_services(
  services: List(ServiceEntry),
  query: ServiceQuery,
) -> List(ServiceEntry) {
  services
  |> filter_by_name(query.name)
  |> filter_by_version(query.version)
  |> filter_by_health_status(query.health_status)
  |> filter_by_node_id(query.node_id)
  |> filter_by_tags(query.tags)
  |> filter_by_metadata(query.metadata_filters)
}

/// Filter services by name
fn filter_by_name(
  services: List(ServiceEntry),
  name_filter: Option(String),
) -> List(ServiceEntry) {
  case name_filter {
    Some(name) -> list.filter(services, fn(service) { service.name == name })
    None -> services
  }
}

/// Filter services by version
fn filter_by_version(
  services: List(ServiceEntry),
  version_filter: Option(String),
) -> List(ServiceEntry) {
  case version_filter {
    Some(version) ->
      list.filter(services, fn(service) { service.version == version })
    None -> services
  }
}

/// Filter services by health status
fn filter_by_health_status(
  services: List(ServiceEntry),
  health_filter: Option(HealthStatus),
) -> List(ServiceEntry) {
  case health_filter {
    Some(health) ->
      list.filter(services, fn(service) { service.health_status == health })
    None -> services
  }
}

/// Filter services by node ID
fn filter_by_node_id(
  services: List(ServiceEntry),
  node_filter: Option(NodeId),
) -> List(ServiceEntry) {
  case node_filter {
    Some(node_id) ->
      list.filter(services, fn(service) { service.node_id == node_id })
    None -> services
  }
}

/// Filter services by tags
fn filter_by_tags(
  services: List(ServiceEntry),
  tag_filters: List(String),
) -> List(ServiceEntry) {
  case tag_filters {
    [] -> services
    _ ->
      list.filter(services, fn(service) {
        list.all(tag_filters, fn(required_tag) {
          list.contains(service.tags, required_tag)
        })
      })
  }
}

/// Filter services by metadata
fn filter_by_metadata(
  services: List(ServiceEntry),
  metadata_filters: Dict(String, String),
) -> List(ServiceEntry) {
  case dict.is_empty(metadata_filters) {
    True -> services
    False ->
      list.filter(services, fn(service) {
        dict.fold(metadata_filters, True, fn(acc, key, value) {
          acc
          && case dict.get(service.metadata, key) {
            Ok(service_value) -> service_value == value
            Error(_) -> False
          }
        })
      })
  }
}

/// Perform health check for a service
fn perform_health_check(service_entry: ServiceEntry) -> HealthStatus {
  case service_entry.health_endpoint {
    Some(_endpoint) -> {
      // In a real implementation, this would make an HTTP request to the health endpoint
      // For now, we'll simulate a basic health check
      simulate_health_check(service_entry)
    }
    None -> {
      // No health endpoint, assume healthy if recently registered/updated
      let current_time = types.now()
      let time_since_registration = case
        current_time,
        service_entry.registered_at
      {
        types.Timestamp(current), types.Timestamp(registered) ->
          current - registered
      }

      case time_since_registration < 300_000 {
        // 5 minutes
        True -> types.Healthy
        False -> types.Unknown
      }
    }
  }
}

/// Simulate health check (placeholder implementation)
fn simulate_health_check(service_entry: ServiceEntry) -> HealthStatus {
  // Simple simulation based on service characteristics
  case service_entry.health_status {
    types.Healthy -> types.Healthy
    types.Degraded -> types.Degraded
    types.Failed -> types.Failed
    types.NodeDown -> types.Failed
    types.Unknown -> types.Healthy
    // Assume healthy for simulation
  }
}

/// Public API functions
/// Register a service
pub fn register_service(
  discovery: actor.Started(process.Subject(ServiceDiscoveryMessage)),
  service_entry: ServiceEntry,
) -> Nil {
  process.send(discovery.data, RegisterService(service_entry))
}

/// Deregister a service
pub fn deregister_service(
  discovery: actor.Started(process.Subject(ServiceDiscoveryMessage)),
  service_id: ServiceId,
) -> Nil {
  process.send(discovery.data, DeregisterService(service_id))
}

/// Update a service entry
pub fn update_service(
  discovery: actor.Started(process.Subject(ServiceDiscoveryMessage)),
  service_entry: ServiceEntry,
) -> Nil {
  process.send(discovery.data, UpdateService(service_entry))
}

/// Discover services based on query
pub fn discover_services(
  discovery: actor.Started(process.Subject(ServiceDiscoveryMessage)),
  query: ServiceQuery,
) -> Nil {
  process.send(discovery.data, DiscoverServices(query))
}

/// Perform health check on a specific service
pub fn health_check_service(
  discovery: actor.Started(process.Subject(ServiceDiscoveryMessage)),
  service_id: ServiceId,
) -> Nil {
  process.send(discovery.data, HealthCheckService(service_id))
}

/// Perform health check on all services
pub fn health_check_all(
  discovery: actor.Started(process.Subject(ServiceDiscoveryMessage)),
) -> Nil {
  process.send(discovery.data, HealthCheckAll)
}

/// Synchronize registry with distributed nodes
pub fn sync_registry(
  discovery: actor.Started(process.Subject(ServiceDiscoveryMessage)),
) -> Nil {
  process.send(discovery.data, SyncRegistry)
}

/// Clear the discovery cache
pub fn clear_cache(
  discovery: actor.Started(process.Subject(ServiceDiscoveryMessage)),
) -> Nil {
  process.send(discovery.data, ClearCache)
}

/// Get registry statistics
pub fn get_registry_stats(
  discovery: actor.Started(process.Subject(ServiceDiscoveryMessage)),
) -> Nil {
  process.send(discovery.data, GetRegistryStats)
}

/// Shutdown the service discovery
pub fn shutdown(
  discovery: actor.Started(process.Subject(ServiceDiscoveryMessage)),
) -> Nil {
  process.send(discovery.data, Shutdown)
}

/// Utility functions for creating service entries and queries
/// Create a new service entry
pub fn new_service_entry(
  id: ServiceId,
  name: String,
  version: String,
  node_id: NodeId,
  address: String,
  port: Int,
) -> ServiceEntry {
  ServiceEntry(
    id: id,
    name: name,
    version: version,
    node_id: node_id,
    address: address,
    port: port,
    health_endpoint: None,
    health_status: types.Unknown,
    metadata: dict.new(),
    tags: [],
    registered_at: types.now(),
    last_health_check: types.now(),
    health_check_interval: 30_000,
    // 30 seconds
    ttl: None,
  )
}

/// Create a new service query
pub fn new_service_query() -> ServiceQuery {
  ServiceQuery(
    name: None,
    version: None,
    tags: [],
    health_status: None,
    node_id: None,
    metadata_filters: dict.new(),
  )
}

/// Add name filter to service query
pub fn with_name(query: ServiceQuery, name: String) -> ServiceQuery {
  ServiceQuery(..query, name: Some(name))
}

/// Add version filter to service query
pub fn with_version(query: ServiceQuery, version: String) -> ServiceQuery {
  ServiceQuery(..query, version: Some(version))
}

/// Add health status filter to service query
pub fn with_health_status(
  query: ServiceQuery,
  health: HealthStatus,
) -> ServiceQuery {
  ServiceQuery(..query, health_status: Some(health))
}

/// Add node ID filter to service query
pub fn with_node_id(query: ServiceQuery, node_id: NodeId) -> ServiceQuery {
  ServiceQuery(..query, node_id: Some(node_id))
}

/// Add tags to service query
pub fn with_tags(query: ServiceQuery, tags: List(String)) -> ServiceQuery {
  ServiceQuery(..query, tags: tags)
}

/// Add metadata filter to service query
pub fn with_metadata(
  query: ServiceQuery,
  key: String,
  value: String,
) -> ServiceQuery {
  let updated_filters = dict.insert(query.metadata_filters, key, value)
  ServiceQuery(..query, metadata_filters: updated_filters)
}
