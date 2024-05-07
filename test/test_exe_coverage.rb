# frozen_string_literal: true

require "test_helper"

class TestExeCoverage < Minitest::Test
  def test_coverage
    assert_equal 0, RaaP::CLI.new([
      "--log-level", "info",
      "--timeout", "0",
      "--size-to", "10",
      "--coverage",
      "Test::Coverage",
    ]).load.run
  end
end
