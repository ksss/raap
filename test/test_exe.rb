# frozen_string_literal: true

require "test_helper"
require "test"

class TestExe < Minitest::Test
  def test_exe
    RaaP::CLI.new([
      "--log-level", "info",
      "--timeout", "1",
      "--size-by", "5",
      "Test::*"
    ]).load.run
  end

  def test_exe_with_args
    RaaP::CLI.new([
      "--log-level", "info",
      "--timeout", "1",
      "--size-by", "1",
      "Test::List[Integer]",
    ]).load.run
  end
end
