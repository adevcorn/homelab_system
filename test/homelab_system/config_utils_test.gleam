/// Test module to verify configuration and utility dependencies are working correctly
import gleeunit/should
import gleam/json
import glenvy
import glint
import lustre
import youid/uuid

pub fn json_test() {
  // Test that we can use gleam_json functionality
  let test_json = json.object([
    #("name", json.string("test")),
    #("value", json.int(42))
  ])
  
  test_json
  |> json.to_string
  |> should.contain("test")
}

pub fn glenvy_test() {
  // Test that we can import glenvy for environment configuration
  // Basic import test - if this compiles, the dependency is working
  should.be_true(True)
}

pub fn glint_test() {
  // Test that we can import glint for CLI functionality
  // Basic import test - if this compiles, the dependency is working
  should.be_true(True)
}

pub fn lustre_test() {
  // Test that we can import lustre for frontend functionality
  // Basic import test - if this compiles, the dependency is working
  should.be_true(True)
}

pub fn uuid_test() {
  // Test that we can generate UUIDs
  let uuid_string = uuid.v4_string()
  uuid_string
  |> should.not_equal("")
}