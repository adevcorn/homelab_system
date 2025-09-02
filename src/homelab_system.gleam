/// Main entry point for the homelab system
/// Initializes and starts the OTP application with proper configuration
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

      // Keep the application running
      // In a real OTP application, this would be handled by the runtime
      run_forever()
    }
    application.StartError(reason) -> {
      io.println("❌ Failed to start Homelab System: " <> reason)
      logging.fatal("Application startup failed: " <> reason)

      // Exit with error code
      // TODO: Use proper exit mechanism when available
      io.println("Exiting...")
    }
  }
}

/// Keep the application running indefinitely
/// In a proper OTP application, this would be managed by the runtime
fn run_forever() -> Nil {
  // TODO: Replace with proper OTP application lifecycle management
  // For now, this is a placeholder that would normally be handled
  // by the BEAM runtime when running as a proper OTP application

  io.println("🔄 Application running... (Press Ctrl+C to stop)")

  // In a real implementation, we would:
  // 1. Set up signal handlers for graceful shutdown
  // 2. Monitor the supervisor tree
  // 3. Handle application lifecycle events
  // 4. Let the OTP runtime manage the application

  Nil
}
