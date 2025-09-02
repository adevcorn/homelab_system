import gleam/json
import gleam/string
import gleeunit/should
import glint
import lustre/element/html
import simplifile
import wisp

pub fn json_test() {
  // Test gleam_json functionality
  let test_object =
    json.object([
      #("name", json.string("homelab_system")),
      #("version", json.string("1.1.0")),
      #("active", json.bool(True)),
      #("port", json.int(8080)),
    ])

  let json_string = json.to_string(test_object)

  json_string
  |> string.contains("homelab_system")
  |> should.be_true()
}

pub fn glint_cli_test() {
  // Test glint CLI framework
  let _app =
    glint.new()
    |> glint.with_name("homelab_system")

  // If this compiles and runs, glint is working
  should.be_true(True)
}

pub fn wisp_web_test() {
  // Test wisp web framework basic functionality
  let _response = wisp.response(200)

  // If this compiles, wisp is available
  should.be_true(True)
}

pub fn lustre_frontend_test() {
  // Test lustre frontend framework
  let _element = html.div([], [html.text("Hello, Homelab!")])

  // If this compiles, lustre is available
  should.be_true(True)
}

pub fn simplifile_integration_test() {
  // Test simplifile for configuration file handling
  let test_path = "/tmp/homelab_config_test.json"

  let config_data =
    json.object([
      #("system_name", json.string("homelab_system")),
      #(
        "components",
        json.array(
          [
            json.string("clustering"),
            json.string("monitoring"),
          ],
          of: fn(x) { x },
        ),
      ),
    ])

  let config_string = json.to_string(config_data)

  case simplifile.write(config_string, to: test_path) {
    Ok(_) -> {
      case simplifile.read(test_path) {
        Ok(content) -> {
          content
          |> string.contains("homelab_system")
          |> should.be_true()

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

pub fn json_array_integration_test() {
  // Test JSON array functionality that we fixed earlier
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
      #("node_id", json.string("test-node-123")),
      #("environment", json.string("test")),
      #("features", features_array),
    ])

  let config_string = json.to_string(config_json)

  // Verify the JSON contains our expected data
  config_string
  |> string.contains("clustering")
  |> should.be_true()

  config_string
  |> string.contains("test-node-123")
  |> should.be_true()
}
