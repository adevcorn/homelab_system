/// Test module to verify core OTP dependencies are working correctly
import gleeunit/should
import gleam/otp/actor
import gleam/erlang/process

pub fn otp_imports_test() {
  // Test that we can import and use basic OTP functionality
  let pid = process.self()
  let same_pid = process.self()
  
  // PIDs should be equal when called from the same process
  pid
  |> should.equal(same_pid)
}

pub fn actor_types_test() {
  // Test that actor types are available
  let _start_error: actor.StartError = actor.InitTimeout
  should.be_true(True)
}