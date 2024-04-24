# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"
require "rubocop/rake_task"

Minitest::TestTask.create do |t|
  base = File.expand_path(".", __dir__)
  t.framework = "require \"test/test_helper\" ;#{t.framework}"
end

RuboCop::RakeTask.new

namespace :steep do
  task :check do
    sh "bundle exec steep check"
  end
end

task default: [:test, :rubocop, 'steep:check']
