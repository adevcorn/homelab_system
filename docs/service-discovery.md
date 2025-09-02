# Service Discovery System

## Overview

The service discovery system provides a mechanism for services in the homelab cluster to register themselves and discover other services. It supports local service registration with built-in caching, health checking, and filtering capabilities.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Service Discovery                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │ Local Registry  │  │     Cache       │  │ Health Check │ │
│  │                 │  │                 │  │   System     │ │
│  │ - Services      │  │ - Query Cache   │  │              │ │
│  │ - Metadata      │  │ - TTL Support   │  │ - Periodic   │ │
│  │ - Health Status │  │                 │  │ - On-Demand  │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Key Components

### Service Registry
- **Local Registry**: Stores service entries for the current node
- **Service Entry**: Contains service metadata, health status, and network information
- **Future**: Distributed registry synchronization across cluster nodes

### Service Discovery Engine
- **Query Processing**: Supports complex filtering by name, version, tags, health status, and metadata
- **Caching**: Query results are cached with configurable TTL to improve performance
- **Health Checking**: Automatic and on-demand health status updates

### Health Monitoring
- **Endpoint-based**: Services can provide health check endpoints
- **Periodic Checks**: Configurable intervals for automatic health monitoring
- **Status Tracking**: Healthy, Degraded, Unhealthy, Unknown states

## Data Structures

### ServiceEntry

```gleam
pub type ServiceEntry {
  ServiceEntry(
    id: ServiceId,                    // Unique service identifier
    name: String,                     // Service name (e.g., "web-api")
    version: String,                  // Service version (e.g., "1.2.3")
    node_id: NodeId,                  // Node hosting the service
    address: String,                  // Network address
    port: Int,                        // Network port
    health_endpoint: Option(String),  // Health check endpoint
    health_status: HealthStatus,      // Current health status
    metadata: Dict(String, String),   // Key-value metadata
    tags: List(String),               // Service tags
    registered_at: Timestamp,         // Registration timestamp
    last_health_check: Timestamp,     // Last health check time
    health_check_interval: Int,       // Health check interval (ms)
    ttl: Option(Int),                 // Service TTL (ms)
  )
}
```

### ServiceQuery

```gleam
pub type ServiceQuery {
  ServiceQuery(
    name: Option(String),                    // Filter by service name
    version: Option(String),                 // Filter by version
    tags: List(String),                      // Must have all tags
    health_status: Option(HealthStatus),     // Filter by health status
    node_id: Option(NodeId),                 // Filter by node
    metadata_filters: Dict(String, String), // Metadata key-value filters
  )
}
```

## API Reference

### Starting the Service Discovery

```gleam
import homelab_system/cluster/discovery
import homelab_system/utils/types

let node_id = types.NodeId("worker-node-1")
let cluster_name = "homelab-cluster"

case discovery.start_link(node_id, cluster_name) {
  Ok(discovery_actor) -> {
    // Service discovery is now running
  }
  Error(err) -> {
    // Handle startup error
  }
}
```

### Service Registration

```gleam
let service_entry = 
  discovery.new_service_entry(
    types.ServiceId("web-api-1"),
    "web-api",
    "1.0.0",
    node_id,
    "192.168.1.100",
    8080
  )
  |> discovery.ServiceEntry(
    .._, 
    health_endpoint: Some("/health"),
    tags: ["api", "web", "production"],
    metadata: dict.new()
      |> dict.insert("team", "platform")
      |> dict.insert("environment", "prod")
  )

discovery.register_service(discovery_actor, service_entry)
```

### Service Discovery

```gleam
let query = 
  discovery.new_service_query()
  |> discovery.with_name("web-api")
  |> discovery.with_health_status(types.Healthy)
  |> discovery.with_tags(["production"])
  |> discovery.with_metadata("team", "platform")

discovery.discover_services(discovery_actor, query)
```

### Health Checking

```gleam
// Check specific service
let service_id = types.ServiceId("web-api-1")
discovery.health_check_service(discovery_actor, service_id)

// Check all services
discovery.health_check_all(discovery_actor)
```

## Configuration

### Service Discovery State

```gleam
pub type ServiceDiscoveryState {
  ServiceDiscoveryState(
    local_registry: Dict(String, ServiceEntry),
    cache: Dict(String, CacheEntry),
    node_id: NodeId,
    cluster_name: String,
    health_check_interval: Int,    // Default: 30 seconds
    cache_ttl: Int,                // Default: 1 minute
    registry_sync_interval: Int,   // Default: 10 seconds (future)
    status: ServiceStatus,
  )
}
```

## Usage Examples

### Basic Web API Service

```gleam
// Register a web API service
let api_service = 
  discovery.new_service_entry(
    types.ServiceId("user-api"),
    "user-api",
    "2.1.0",
    node_id,
    "localhost",
    3000
  )
  |> discovery.ServiceEntry(
    .._,
    health_endpoint: Some("/api/health"),
    tags: ["api", "users", "microservice"],
    metadata: dict.new()
      |> dict.insert("database", "postgresql")
      |> dict.insert("cache", "redis")
  )

discovery.register_service(discovery_actor, api_service)
```

### Database Service Discovery

```gleam
// Find all healthy database services
let db_query = 
  discovery.new_service_query()
  |> discovery.with_tags(["database"])
  |> discovery.with_health_status(types.Healthy)

discovery.discover_services(discovery_actor, db_query)
```

### Load Balancer Service Discovery

```gleam
// Find all web services for load balancing
let web_services_query = 
  discovery.new_service_query()
  |> discovery.with_tags(["web", "api"])
  |> discovery.with_health_status(types.Healthy)
  |> discovery.with_metadata("environment", "production")

discovery.discover_services(discovery_actor, web_services_query)
```

## Best Practices

### Service Registration
- Use descriptive service names and consistent versioning
- Include health check endpoints when possible
- Tag services appropriately for discovery
- Set reasonable health check intervals

### Service Discovery
- Cache query results when appropriate
- Use specific queries to reduce network overhead
- Monitor service health status
- Handle service unavailability gracefully

### Health Checking
- Implement lightweight health endpoints
- Return appropriate HTTP status codes
- Include dependency checks in health endpoints
- Monitor and alert on health status changes

## Monitoring and Debugging

### Registry Statistics

```gleam
discovery.get_registry_stats(discovery_actor)
// Returns: local_count, cache_entries
```

### Cache Management

```gleam
// Clear cache to force fresh discovery
discovery.clear_cache(discovery_actor)

// Synchronize registry (placeholder for distributed sync)
discovery.sync_registry(discovery_actor)
```

## Future Enhancements

### Distributed Registry
- **glyn Integration**: Synchronize service registries across cluster nodes
- **Consistency**: Eventual consistency model for distributed service data
- **Partitioning**: Handle network partitions gracefully

### Advanced Health Checking
- **HTTP Health Checks**: Automatic HTTP endpoint monitoring
- **Custom Health Checks**: Plugin system for custom health verification
- **Circuit Breaker**: Automatic service isolation on repeated failures

### Service Versioning
- **Semantic Versioning**: Support for version constraints and compatibility
- **Blue-Green Deployments**: Version-aware service routing
- **Canary Releases**: Gradual traffic shifting between versions

### Performance Optimizations
- **Bulk Operations**: Register/deregister multiple services efficiently
- **Streaming Updates**: Real-time service status updates
- **Compression**: Compress service metadata for network efficiency

## Error Handling

### Common Errors
- **Service Not Found**: Handle missing services gracefully
- **Network Failures**: Retry mechanisms for distributed operations
- **Health Check Failures**: Automatic service marking and retry logic
- **Registry Sync Issues**: Fallback to local registry when distributed sync fails

### Error Recovery
- **Exponential Backoff**: For retry operations
- **Circuit Breaker Pattern**: Prevent cascading failures
- **Graceful Degradation**: Continue with local-only operation when needed

## Integration Points

### Node Manager
- Service discovery integrates with the cluster node manager
- Services are associated with specific nodes
- Node failures trigger service cleanup

### Agent Framework
- Agents can register themselves as services
- Service discovery helps agents find each other
- Health checking integrates with agent lifecycle

### Gateway API
- HTTP API gateway uses service discovery for routing
- Load balancing based on healthy service instances
- Service metadata drives routing decisions