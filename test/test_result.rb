# frozen_string_literal: true

require "test_helper"

class TestResult < Minitest::Test
  include RaaP::Result

  def test_success_called_str
    sc = [:call, 123, :to_s, [], {}, nil]
    s = Success.new(symbolic_call: sc, return_value: "123")
    assert_equal <<~CODE.chomp, s.called_str
      123.to_s() -> "123"[String]
    CODE
  end

  def test_success_called_str_with_nil
    sc = [:call, 123, :to_s, [], {}, nil]
    s = Success.new(symbolic_call: sc, return_value: nil)
    assert_equal <<~CODE.chomp, s.called_str
      123.to_s() -> nil
    CODE
  end

  def test_success_called_str_with_true
    sc = [:call, 123, :to_s, [], {}, nil]
    s = Success.new(symbolic_call: sc, return_value: true)
    assert_equal <<~CODE.chomp, s.called_str
      123.to_s() -> true[bool]
    CODE
  end

  def test_failure_called_str
    sc = [:call, 123, :to_s, [], {}, nil]
    s = Failure.new(symbolic_call: sc, return_value: "123")
    assert_equal <<~CODE.chomp, s.called_str
      123.to_s() -> "123"[String]
    CODE
  end

  def test_failure_called_str_with_nil
    sc = [:call, 123, :to_s, [], {}, nil]
    s = Failure.new(symbolic_call: sc, return_value: nil)
    assert_equal <<~CODE.chomp, s.called_str
      123.to_s() -> nil
    CODE
  end

  def test_failure_called_str_with_true
    sc = [:call, 123, :to_s, [], {}, nil]
    s = Failure.new(symbolic_call: sc, return_value: true)
    assert_equal <<~CODE.chomp, s.called_str
      123.to_s() -> true[bool]
    CODE
  end

  def test_failure_called_str_with_exception
    sc = [:call, 123, :to_s, [], {}, nil]
    s = Failure.new(symbolic_call: sc, return_value: "123", exception: TypeError.new("err"))
    assert_equal <<~CODE.chomp, s.called_str
      123.to_s() -> raised TypeError
    CODE
  end
end
