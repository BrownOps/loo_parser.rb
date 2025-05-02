# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = "--format documentation" # Or your preferred format
end

RuboCop::RakeTask.new(:rubocop)

# Default task
task default: %i[spec rubocop]
