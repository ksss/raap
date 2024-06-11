# frozen_string_literal: true

require "test_helper"

class TestExeSearch < Minitest::Test
  def test_exe_with_search
    assert_equal 0, RaaP::CLI.new([
      "--log-level", "info",
      "--timeout", "0.5",
      "--size-by", "5",
      "Test::*",
      "!Test::Property#alias",
      "!Test::List",
      "!Test::SkipPrefix#should_skip",
      "!Test::NameErrorLogging",
      "!Test::TypeErrorIsFail",
      "!Test::ExceptionWithBot",
      "!Test::Coverage",
      "!Test::BlockArgsCheck",
      "!Test::Set"
    ]).load.run
  end
end
