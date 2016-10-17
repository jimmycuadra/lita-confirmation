require "simplecov"
require "coveralls"
SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.start {
  add_filter "/spec/"
  add_filter "/.bundle/"
}

require "lita-confirmation"
require "lita/rspec"

Lita.version_3_compatibility_mode = false
