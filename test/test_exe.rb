# frozen_string_literal: true

require "test_helper"

class TestExe < Minitest::Test
  def capture
    orig = $stdout
    $stdout = StringIO.new
    yield $stdout
  ensure
    $stdout = orig
  end

  def test_skip_by_name_error
    assert_equal 0, RaaP::CLI.new([
      "--log-level", "info",
      "--size-by", "5",
      "Test::NameErrorLogging",
    ]).load.run
  end

  def test_fail_type_error
    capture do |io|
      assert_equal 1, RaaP::CLI.new([
        "--log-level", "info",
        "--size-by", "1",
        "Test::TypeErrorIsFail",
      ]).load.run
      assert_match "1) Failure:", io.string
    end
  end

  def test_exception_with_bot
    original_logger = RaaP.logger
    RaaP.logger = Logger.new(io = StringIO.new)
    assert_raises Test::TestException do
      RaaP::CLI.new([
        "--log-level", "info",
        "--size-by", "1",
        "Test::ExceptionWithBot",
      ]).load.run
    end
    assert_match '[Test::TestException] class is not supported to check `bot` type', io.string
  ensure
    RaaP.logger = original_logger
  end

  def test_alias_stdout
    capture do |io|
      status = RaaP::CLI.new([
        "--log-level", "info",
        "--timeout", "1",
        "--size-to", "10",
        "Test::Property#alias"
      ]).load.run
      assert status == 1
      assert_match "def alias: () -> bool", io.string
      assert_match "  in test/test.rbs:4:4...4:32", io.string
    end
  end

  def test_exe_array_compact
    assert_equal 0, RaaP::CLI.new([
      "--log-level", "info",
      "--timeout", "1",
      "--size-by", "10",
      "::Array#compact!",
    ]).load.run
  end

  def test_exe_array_compact_with_args
    assert_equal 0, RaaP::CLI.new([
      "--log-level", "info",
      "--timeout", "1",
      "--size-by", "10",
      "::Array[Integer?]#compact!",
    ]).load.run
  end

  def test_block_to_value
    assert_equal 0, RaaP::CLI.new([
      "--log-level", "warn",
      "--timeout", "1",
      "--size-by", "2",
      "::Enumerable[Integer]#max_by",
    ]).load.run
  end

  def test_exe_without_args
    assert_equal 0, RaaP::CLI.new([
      "--log-level", "info",
      "--timeout", "0",
      "--size-by", "20",
      "Test::List",
    ]).load.run
  end

  def test_exe_with_args
    assert_equal 0, RaaP::CLI.new([
      "--log-level", "info",
      "--timeout", "0",
      "--size-to", "20",
      "Test::List[Integer]",
    ]).load.run
  end
end
