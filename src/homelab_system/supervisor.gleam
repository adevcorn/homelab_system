/// Main supervision tree for the homelab system
/// Defines the top-level supervisor that manages all core system components

import gleam/otp/static_supervisor.{type Supervisor} as supervisor
import gleam/otp/actor

/// Initialize the main supervision tree for the homelab system
pub fn start_link() -> actor.StartResult(Supervisor) {
  supervisor.new(supervisor.OneForOne)
  // Add child specs for core system components
  // |> supervisor.add(some_child_spec)
  |> supervisor.start
}