import gleam/dict
import gleam/list
import gleam/string
import gleeunit/should
import homelab_system/messaging/pubsub

pub fn new_pubsub_test() {
  let system = pubsub.new()

  system.active
  |> should.be_true()

  system.message_count
  |> should.equal(0)

  dict.size(system.topics)
  |> should.equal(0)
}

pub fn start_stop_test() {
  let system = pubsub.new()

  // Test starting an already active system
  case pubsub.start(system) {
    Ok(started_system) -> {
      started_system.active
      |> should.be_true()
    }
    Error(_) -> should.fail()
  }

  // Test stopping the system
  let stopped_system = pubsub.stop(system)

  stopped_system.active
  |> should.be_false()
}

pub fn subscribe_test() {
  let system = pubsub.new()
  let topic = "test.events"

  // Create a test subscriber
  let test_subscriber = fn(_topic, _message) {
    // This is a placeholder subscriber for testing
    Nil
  }

  let updated_system = pubsub.subscribe(system, topic, test_subscriber)

  // Check that the topic was added
  pubsub.get_topics(updated_system)
  |> list.contains(topic)
  |> should.be_true()

  // Check subscriber count
  pubsub.get_subscriber_count(updated_system, topic)
  |> should.equal(1)
}

pub fn publish_message_test() {
  let system = pubsub.new()
  let topic = pubsub.system_events

  // Subscribe to the topic
  let test_subscriber = fn(_topic, _message) {
    // Placeholder subscriber
    Nil
  }

  let subscribed_system = pubsub.subscribe(system, topic, test_subscriber)

  // Create a test message
  let message = pubsub.system_startup_message("1.1.0")

  // Publish the message
  let updated_system = pubsub.publish(subscribed_system, topic, message)

  // Check that message count increased
  pubsub.get_message_count(updated_system)
  |> should.equal(1)
}

pub fn publish_to_inactive_system_test() {
  let system = pubsub.new()
  let stopped_system = pubsub.stop(system)

  let message = pubsub.system_startup_message("1.1.0")
  let result_system =
    pubsub.publish(stopped_system, pubsub.system_events, message)

  // Message count should remain 0 for inactive system
  pubsub.get_message_count(result_system)
  |> should.equal(0)
}

pub fn unsubscribe_test() {
  let system = pubsub.new()
  let topic = "test.events"

  let test_subscriber = fn(_topic, _message) { Nil }
  let subscribed_system = pubsub.subscribe(system, topic, test_subscriber)

  // Verify subscription exists
  pubsub.get_subscriber_count(subscribed_system, topic)
  |> should.equal(1)

  // Unsubscribe
  let unsubscribed_system = pubsub.unsubscribe(subscribed_system, topic)

  // Verify subscription is removed
  pubsub.get_subscriber_count(unsubscribed_system, topic)
  |> should.equal(0)
}

pub fn broadcast_test() {
  let system = pubsub.new()

  let test_subscriber = fn(_topic, _message) { Nil }

  // Subscribe to multiple topics
  let multi_subscribed_system =
    system
    |> pubsub.subscribe(pubsub.system_events, test_subscriber)
    |> pubsub.subscribe(pubsub.node_events, test_subscriber)
    |> pubsub.subscribe(pubsub.health_events, test_subscriber)

  let message = pubsub.system_startup_message("1.1.0")

  // Broadcast to all topics
  let broadcasted_system = pubsub.broadcast(multi_subscribed_system, message)

  // Message count should equal number of topics (3)
  pubsub.get_message_count(broadcasted_system)
  |> should.equal(3)
}

pub fn message_creation_test() {
  // Test system messages
  let startup_msg = pubsub.system_startup_message("1.1.0")
  let _shutdown_msg = pubsub.system_shutdown_message("manual")

  // Test node messages
  let _join_msg = pubsub.node_join_message("node-1", "cluster-1")
  let _leave_msg = pubsub.node_leave_message("node-1", "shutdown")

  // Test health messages
  let _health_msg =
    pubsub.health_status_message("api", "healthy", "all checks passed")

  // Test config messages
  let _config_msg = pubsub.config_change_message("port", "8080", "8081")

  // Test message to string conversion
  let startup_str = pubsub.message_to_string(startup_msg)

  // Basic test that the string contains expected content
  should.be_true(string.contains(startup_str, "SystemEvent"))
  should.be_true(string.contains(startup_str, "startup"))
}

pub fn topic_constants_test() {
  // Test that topic constants are strings
  pubsub.system_events
  |> should.equal("homelab.system.events")

  pubsub.node_events
  |> should.equal("homelab.node.events")

  pubsub.cluster_events
  |> should.equal("homelab.cluster.events")

  pubsub.health_events
  |> should.equal("homelab.health.events")

  pubsub.config_events
  |> should.equal("homelab.config.events")

  pubsub.api_events
  |> should.equal("homelab.api.events")

  pubsub.metrics_events
  |> should.equal("homelab.metrics.events")
}

pub fn get_topics_test() {
  let system = pubsub.new()
  let test_subscriber = fn(_topic, _message) { Nil }

  // Initially no topics
  pubsub.get_topics(system)
  |> list.length()
  |> should.equal(0)

  // Add some topics
  let updated_system =
    system
    |> pubsub.subscribe("topic1", test_subscriber)
    |> pubsub.subscribe("topic2", test_subscriber)
    |> pubsub.subscribe("topic3", test_subscriber)

  // Should have 3 topics
  pubsub.get_topics(updated_system)
  |> list.length()
  |> should.equal(3)
}

pub fn is_active_test() {
  let system = pubsub.new()

  // New system should be active
  pubsub.is_active(system)
  |> should.be_true()

  // Stopped system should be inactive
  let stopped_system = pubsub.stop(system)
  pubsub.is_active(stopped_system)
  |> should.be_false()
}
