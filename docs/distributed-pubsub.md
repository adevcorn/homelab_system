# Distributed PubSub Messaging System

## Overview

The distributed PubSub messaging system provides reliable, scalable publish-subscribe messaging for the homelab cluster. It supports message persistence, delivery guarantees, topic-based routing, and cluster-wide distribution.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          Distributed PubSub System                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌──────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │ Message Store   │  │ Subscription     │  │ Topic Manager   │  │ Cluster     │ │
│  │                 │  │ Registry         │  │                 │  │ Sync        │ │
│  │ - Persistence   │  │                  │  │ - Routing       │  │             │ │
│  │ - TTL Support   │  │ - Pattern Match  │  │ - Retention     │  │ - Node Sync │ │
│  │ - Acknowledgment│  │ - Filtering      │  │ - Statistics    │  │ - Discovery │ │
│  │ - Retry Logic   │  │ - Delivery Track │  │                 │  │             │ │
│  └─────────────────┘  └──────────────────┘  └─────────────────┘  └─────────────┘ │
│                                                                                 │
│  ┌─────────────────┐  ┌──────────────────┐  ┌─────────────────┐                │
│  │ Priority Queue  │  │ Health Monitor   │  │ Maintenance     │                │
│  │                 │  │                  │  │                 │                │
│  │ - Critical      │  │ - Node Health    │  │ - Cleanup       │                │
│  │ - High          │  │ - Message Track  │  │ - Compaction    │                │
│  │ - Medium        │  │ - Error Recovery │  │ - Statistics    │                │
│  │ - Low           │  │                  │  │                 │                │
│  └─────────────────┘  └──────────────────┘  └─────────────────┘                │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Key Features

### Message Delivery Guarantees
- **At-Most-Once**: Fire-and-forget delivery
- **At-Least-Once**: Retry until acknowledged
- **Exactly-Once**: Deduplication and guaranteed delivery

### Message Persistence
- Configurable retention policies (time, count, size)
- Message expiration and cleanup
- Store compaction for performance

### Topic Pattern Matching
- **Exact**: `"system.health"` matches exactly
- **Wildcard**: `"system.*"` matches `"system.health"`, `"system.status"`
- **Multi-level**: `"system.**"` matches `"system.health.cpu"`, `"system.alerts.disk"`
- **Regex**: Custom pattern matching with regular expressions

### Priority System
- **Critical**: Immediate processing
- **High**: Priority processing
- **Medium**: Normal processing (default)
- **Low**: Background processing

## Data Structures

### MessageEnvelope

```gleam
pub type MessageEnvelope {
  MessageEnvelope(
    id: String,                        // Unique message identifier
    topic: String,                     // Target topic
    payload: String,                   // Message payload (JSON)
    sender_id: NodeId,                 // Sending node
    timestamp: Timestamp,              // Creation time
    priority: MessagePriority,         // Message priority
    delivery_guarantee: DeliveryGuarantee,
    ttl: Option(Int),                  // Time to live (ms)
    retry_count: Int,                  // Current retry count
    max_retries: Int,                  // Maximum retries
    correlation_id: Option(String),    // Request/response correlation
    headers: Dict(String, String),     // Custom headers
  )
}
```

### Subscription

```gleam
pub type Subscription {
  Subscription(
    id: String,                        // Unique subscription ID
    node_id: NodeId,                   // Subscribing node
    pattern: TopicPattern,             // Topic pattern to match
    handler: String,                   // Handler identifier
    delivery_guarantee: DeliveryGuarantee,
    filter_expression: Option(String), // Message filtering
    created_at: Timestamp,
    active: Bool,
  )
}
```

### RetentionPolicy

```gleam
pub type RetentionPolicy {
  RetentionPolicy(
    max_messages: Option(Int),         // Maximum messages to retain
    max_age: Option(Int),              // Maximum age in milliseconds
    max_size: Option(Int),             // Maximum size in bytes
  )
}
```

## API Reference

### Starting the Distributed PubSub

```gleam
import homelab_system/messaging/distributed_pubsub as pubsub
import homelab_system/utils/types

let node_id = types.NodeId("worker-node-1")
let cluster_name = "homelab-cluster"

case pubsub.start_link(node_id, cluster_name) {
  Ok(pubsub_actor) -> {
    // Distributed PubSub is now running
  }
  Error(err) -> {
    // Handle startup error
  }
}
```

### Publishing Messages

```gleam
// Create message envelope
let envelope = 
  pubsub.new_message_envelope(
    "msg-001",
    "system.alerts.cpu",
    "{\"cpu_usage\": 85, \"threshold\": 80}",
    node_id
  )
  |> pubsub.MessageEnvelope(
    .._,
    priority: pubsub.High,
    delivery_guarantee: pubsub.AtLeastOnce,
    ttl: Some(300_000), // 5 minutes
    headers: dict.new()
      |> dict.insert("source", "monitoring-agent")
      |> dict.insert("severity", "warning")
  )

// Publish message
pubsub.publish(pubsub_actor, envelope)
```

### Creating Subscriptions

```gleam
// Create subscription with wildcard pattern
let subscription = 
  pubsub.new_subscription(
    "cpu-alert-handler",
    node_id,
    pubsub.Wildcard("system.alerts.*"),
    "alert-processor"
  )
  |> pubsub.Subscription(
    .._,
    delivery_guarantee: pubsub.ExactlyOnce,
    filter_expression: Some("severity == 'critical'"),
  )

// Subscribe to topic
pubsub.subscribe(pubsub_actor, subscription)
```

### Topic Management

```gleam
// Create topic with custom retention
let retention = pubsub.RetentionPolicy(
  max_messages: Some(5000),
  max_age: Some(7_200_000), // 2 hours
  max_size: Some(50 * 1024 * 1024) // 50MB
)

pubsub.create_topic(pubsub_actor, "events.user.actions", retention)

// List all topics
pubsub.list_topics(pubsub_actor)

// Get topic information
pubsub.get_topic_info(pubsub_actor, "events.user.actions")

// Delete topic
pubsub.delete_topic(pubsub_actor, "events.user.actions")
```

### Message Acknowledgment

```gleam
// Acknowledge successful message processing
let ack = pubsub.new_message_ack(
  "msg-001",
  "cpu-alert-handler", 
  pubsub.Acknowledged
)

pubsub.acknowledge_message(pubsub_actor, ack)

// Report failed message processing
let failed_ack = pubsub.MessageAck(
  message_id: "msg-002",
  subscription_id: "disk-monitor",
  status: pubsub.Failed,
  timestamp: types.now(),
  error_details: Some("Handler timeout after 30s")
)

pubsub.acknowledge_message(pubsub_actor, failed_ack)
```

## Usage Examples

### System Health Monitoring

```gleam
// Publisher (Health Monitor Agent)
let health_envelope = 
  pubsub.new_message_envelope(
    "health-001",
    "system.health.node.cpu",
    "{\"node_id\": \"worker-1\", \"cpu_usage\": 75, \"timestamp\": 1640995200}",
    node_id
  )
  |> pubsub.MessageEnvelope(._, priority: pubsub.Medium)

pubsub.publish(pubsub_actor, health_envelope)

// Subscriber (Dashboard Service)
let dashboard_sub = 
  pubsub.new_subscription(
    "dashboard-health",
    dashboard_node_id,
    pubsub.MultiLevel("system.health.**"),
    "health-dashboard-handler"
  )

pubsub.subscribe(pubsub_actor, dashboard_sub)
```

### Alert System

```gleam
// Critical Alert Publisher
let critical_alert = 
  pubsub.new_message_envelope(
    "alert-critical-001",
    "alerts.critical.disk.full",
    "{\"node\": \"storage-1\", \"disk\": \"/dev/sda1\", \"usage\": 95}",
    monitoring_node_id
  )
  |> pubsub.MessageEnvelope(
    .._,
    priority: pubsub.Critical,
    delivery_guarantee: pubsub.ExactlyOnce,
    ttl: Some(600_000) // 10 minutes
  )

pubsub.publish(pubsub_actor, critical_alert)

// Alert Handler Subscription
let alert_handler_sub = 
  pubsub.new_subscription(
    "alert-handler",
    alert_node_id,
    pubsub.Wildcard("alerts.critical.*"),
    "critical-alert-processor"
  )
  |> pubsub.Subscription(
    .._,
    delivery_guarantee: pubsub.ExactlyOnce,
    filter_expression: Some("usage > 90")
  )

pubsub.subscribe(pubsub_actor, alert_handler_sub)
```

### Configuration Updates

```gleam
// Configuration Change Publisher
let config_update = 
  pubsub.new_message_envelope(
    "config-update-001",
    "config.updates.monitoring.thresholds",
    "{\"cpu_threshold\": 80, \"memory_threshold\": 85, \"applied_by\": \"admin\"}",
    config_node_id
  )
  |> pubsub.MessageEnvelope(
    .._,
    priority: pubsub.High,
    delivery_guarantee: pubsub.AtLeastOnce
  )

pubsub.publish(pubsub_actor, config_update)

// Service Configuration Subscriber
let service_config_sub = 
  pubsub.new_subscription(
    "service-config-updater",
    service_node_id,
    pubsub.Exact("config.updates.monitoring.thresholds"),
    "config-update-handler"
  )

pubsub.subscribe(pubsub_actor, service_config_sub)
```

## Maintenance Operations

### Message Cleanup and Compaction

```gleam
// Clean up expired messages
pubsub.cleanup_expired_messages(pubsub_actor)

// Compact message store (remove acknowledged messages)
pubsub.compact_message_store(pubsub_actor)

// Retry failed messages
pubsub.retry_failed_messages(pubsub_actor)
```

### Cluster Synchronization

```gleam
// Synchronize topics across cluster
pubsub.sync_topics(pubsub_actor)

// Synchronize subscriptions across cluster
pubsub.sync_subscriptions(pubsub_actor)
```

### System Statistics

```gleam
// Get system statistics
pubsub.get_statistics(pubsub_actor)
// Logs: Messages: 1250, Subscriptions: 15, Topics: 8
```

## Best Practices

### Message Design
- Use hierarchical topic naming: `system.component.metric`
- Keep message payloads small and focused
- Include necessary metadata in headers
- Use correlation IDs for request-response patterns

### Subscription Patterns
- Use specific patterns when possible to reduce overhead
- Implement idempotent message handlers
- Handle duplicate messages gracefully
- Use appropriate delivery guarantees for use case

### Performance Optimization
- Set reasonable TTL values to prevent message buildup
- Use message priorities to ensure critical messages are processed first
- Monitor subscription performance and adjust filters
- Regular cleanup and compaction

### Error Handling
- Implement proper error handling in message handlers
- Use acknowledgments to track message processing
- Monitor failed message patterns
- Set up alerts for high failure rates

## Monitoring and Debugging

### Health Checks
- Monitor message processing rates
- Track acknowledgment ratios
- Watch for growing retry queues
- Monitor topic subscription counts

### Troubleshooting
```gleam
// Check message store size and cleanup if needed
pubsub.get_statistics(pubsub_actor)
pubsub.cleanup_expired_messages(pubsub_actor)
pubsub.compact_message_store(pubsub_actor)

// Verify subscriptions are active
pubsub.list_topics(pubsub_actor)

// Check for failed messages
pubsub.retry_failed_messages(pubsub_actor)
```

## Integration with Other Systems

### Service Discovery Integration
- Messages can be routed based on service discovery information
- Service health changes can trigger message routing updates
- Dynamic subscription management based on available services

### Node Manager Integration
- Node join/leave events trigger subscription cleanup
- Message distribution adapts to cluster topology changes
- Health status affects message routing decisions

### Agent Framework Integration
- Agents can publish status updates and metrics
- Inter-agent communication via topic-based messaging
- Centralized logging and monitoring through message streams

## Future Enhancements

### Full Distributed Implementation
- **glubsub Integration**: Complete cluster-wide message distribution
- **Consensus Protocol**: Ensure message ordering across nodes
- **Partition Tolerance**: Handle network splits gracefully

### Advanced Features
- **Message Batching**: Improve throughput with batch processing
- **Flow Control**: Prevent overwhelming slow subscribers
- **Dead Letter Queue**: Handle permanently failed messages
- **Message Encryption**: Secure sensitive message content

### Performance Improvements
- **Message Compression**: Reduce network bandwidth usage
- **Connection Pooling**: Optimize network connections
- **Async Handlers**: Non-blocking message processing
- **Metrics Collection**: Detailed performance monitoring

## Error Handling

### Common Scenarios
- **Message Too Large**: Implement size limits and chunking
- **Subscription Not Found**: Handle dynamic subscription changes
- **Node Unreachable**: Implement timeout and retry logic
- **Storage Full**: Automatic cleanup and alerting

### Recovery Strategies
- **Exponential Backoff**: For retry operations
- **Circuit Breaker**: Prevent cascading failures
- **Graceful Degradation**: Continue with reduced functionality
- **Manual Recovery**: Tools for administrative intervention

## Security Considerations

### Message Authentication
- Verify message sender identity
- Implement message signing for critical topics
- Rate limiting to prevent abuse

### Access Control
- Topic-based permissions
- Subscription authorization
- Administrative operation restrictions

### Data Protection
- Encrypt sensitive message content
- Audit trail for message access
- Compliance with data protection regulations