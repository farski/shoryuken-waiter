require "coveralls"
Coveralls.wear!

require "dotenv"
Dotenv.load

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "shoryuken/waiter"
require "shoryuken"

config_file = File.join(File.expand_path("../..", __FILE__), "test", "fixtures", "shoryuken.yml")
Shoryuken::EnvironmentLoader.load(config_file: config_file)

require "minitest/autorun"
