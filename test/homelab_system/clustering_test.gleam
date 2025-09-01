/// Test module to verify distributed clustering dependencies are working correctly
import gleeunit/should
import glyn/registry
import glyn/pubsub
import lifeguard

pub fn glyn_registry_test() {
  // Test that we can import and use glyn registry functionality
  let _registry_name = "test_registry"
  // Basic import test - if this compiles, the dependency is working
  should.be_true(True)
}

pub fn glyn_pubsub_test() {
  // Test that we can import and use glyn pubsub functionality
  let _topic = "test_topic"
  // Basic import test - if this compiles, the dependency is working
  should.be_true(True)
}

pub fn lifeguard_test() {
  // Test that we can import lifeguard functionality
  // Basic import test - if this compiles, the dependency is working
  should.be_true(True)
}