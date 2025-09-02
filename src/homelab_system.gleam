/// Main entry point for the homelab system
/// Initializes and starts the OTP application with proper configuration
import gleam/erlang/process
import gleam/io
import homelab_system/application
import homelab_system/utils/logging

/// Main function - entry point for the application
pub fn main() -> Nil {
  // Initialize logging
  logging.log_startup("homelab_system", "1.1.0")

  // Start the OTP application
  case application.start() {
    application.StartSuccess(state) -> {
      io.println("✅ Homelab System started successfully!")

      // Log application info
      let info = application.get_info(state)
      logging.info("Application running: " <> info)

      // Keep the application running by blocking the main process
      // The supervisor tree will continue running in the background
      wait_forever()
    }
    application.StartError(reason) -> {
      io.println("❌ Failed to start Homelab System: " <> reason)
      logging.fatal("Application startup failed: " <> reason)

      // Exit with error code
      io.println("Exiting...")
    }
  }
}

/// Keep the application running indefinitely by waiting for system messages
/// This approach blocks the main process while allowing the supervisor tree to run
fn wait_forever() -> Nil {
  io.println("🔄 Application running... (Press Ctrl+C to stop)")

  // Create a selector that will never receive messages, effectively blocking forever
  // This is the proper way to keep a BEAM application alive
  let selector = process.new_selector()
  let _ = process.selector_receive_forever(selector)

  // This should never be reached, but included for completeness
  wait_forever()
}
