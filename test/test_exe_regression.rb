# frozen_string_literal: true

require "test_helper"

class TestExeRegression < Minitest::Test
  def test_exe_with_set_superset_p
    assert_equal 0, RaaP::CLI.new([
      "--log-level", "debug",
      "--size-to", "2",
      "Test::Set[Integer]",
    ]).load.run
  end
end
