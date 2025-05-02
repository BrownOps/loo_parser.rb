# frozen_string_literal: true

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.setup

require_relative "loo_parser/version"
require_relative "loo_parser/parser"
require_relative "loo_parser/cli"

# Main module for the LooParser gem
module LooParser
  class Error < StandardError; end
  # Your code goes here...
end

# Optional: if using Zeitwerk
# loader.eager_load # Optional: If you want to load everything upfront
