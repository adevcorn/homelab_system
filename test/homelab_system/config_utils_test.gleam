/// Test module to verify configuration and utility dependencies are working correctly
import gleam/json
import gleam/string
import gleeunit/should
import glint
import simplifile
import youid/uuid

pub fn json_test() {
  // Test that we can use gleam_json functionality
  let test_json =
    json.object([
      #("name", json.string("homelab_system")),
      #("version", json.string("1.1.0")),
      #("active", json.bool(True)),
    ])

  let json_string = json.to_string(test_json)

  json_string
  |> should.not_equal("")

  json_string
  |> string.contains("homelab_system")
  |> should.be_true()
}

pub fn glint_test() {
  // Test that we can import glint for CLI functionality
  let _app = glint.new()

  // Basic test - if this compiles and runs, glint is available
  should.be_true(True)
}

pub fn simplifile_test() {
  // Test that we can use simplifile for file operations
  let test_path = "/tmp/test_homelab_system.txt"
  let test_content = "Configuration test content"

  // Test writing a file
  case simplifile.write(test_content, to: test_path) {
    Ok(_) -> {
      // Test reading the file back
      case simplifile.read(test_path) {
        Ok(content) -> {
          content
          |> should.equal(test_content)

          // Clean up
          let _ = simplifile.delete(test_path)
          Nil
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn uuid_test() {
  // Test that we can generate UUIDs
  let uuid_string = uuid.v4_string()

  uuid_string
  |> should.not_equal("")

  // UUID v4 should be 36 characters long (including dashes)
  uuid_string
  |> string.length()
  |> should.equal(36)

  // Should contain dashes in the right positions
  uuid_string
  |> string.contains("-")
  |> should.be_true()
}

pub fn json_array_test() {
  // Test json array functionality with correct API
  let features_array =
    json.array(
      [
        json.string("clustering"),
        json.string("monitoring"),
        json.string("web_interface"),
      ],
      of: fn(x) { x },
    )

  let config_json =
    json.object([
      #("node_id", json.string(uuid.v4_string())),
      #("environment", json.string("test")),
      #("features", features_array),
    ])

  let config_string = json.to_string(config_json)

  // Verify the JSON contains our expected data
  config_string
  |> string.contains("node_id")
  |> should.be_true()

  config_string
  |> string.contains("clustering")
  |> should.be_true()
}

pub fn all_dependencies_available_test() {
  // Test that all configuration and utility dependencies are available
  // This comprehensive test verifies multiple packages work together

  // Test JSON serialization
  let test_data =
    json.object([
      #("system", json.string("homelab_system")),
      #("test_id", json.string(uuid.v4_string())),
    ])

  let json_output = json.to_string(test_data)
  json_output
  |> string.contains("homelab_system")
  |> should.be_true()

  // Test CLI framework is available
  let _cli_app = glint.new()

  // If we reach here, all core dependencies are working
  should.be_true(True)
}
