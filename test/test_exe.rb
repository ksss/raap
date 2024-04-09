# frozen_string_literal: true

require "test_helper"
require "test"

class TestExe < Minitest::Test
  RaaP::Type.register("::Test::List") do
    sized do |size|
      list = [:call, Test::List, :new, [], {}, nil]
      arg = type.args[0] ? RaaP::Type.new(type.args[0]) : RaaP::Type.random
      size.times.inject(list) do |r, i|
        [:call, r, :add, [arg.pick(size: i / 2)], {}, nil]
      end
    end
  end

  def test_exe_with_search
    RaaP::CLI.new([
      "--log-level", "info",
      "--timeout", "1",
      "--size-by", "5",
      "Test::*"
    ]).load.run
  end

  def test_exe_without_args
    RaaP::CLI.new([
      "--log-level", "info",
      "--timeout", "1",
      "--size-by", "1",
      "Test::List",
    ]).load.run
  end

  def test_exe_array_compact
    RaaP::CLI.new([
      "--log-level", "info",
      "--timeout", "1",
      "--size-by", "1",
      "::Array#compact!",
    ]).load.run
  end

  def test_exe_array_compact_with_args
    RaaP::CLI.new([
      "--log-level", "info",
      "--timeout", "1",
      "--size-by", "1",
      "::Array[Integer?]#compact!",
    ]).load.run
  end

  def test_exe_with_args
    RaaP::CLI.new([
      "--log-level", "info",
      "--timeout", "1",
      "--size-to", "10",
      "Test::List[Integer]",
    ]).load.run
  end
end
