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

  def test_success_called_str_with_enumerator_empty
    sc = [:call, [], :each, [], {}, nil]
    s = Success.new(symbolic_call: sc, return_value: [].each)
    assert_equal <<~CODE.chomp, s.called_str
      [].each() -> #<Enumerator: []:each>[Enumerator[untyped, Array]]
    CODE
  end

  def test_success_called_str_with_enumerator_limited
    sc = [:call, [1], :cycle, [1], {}, nil]
    s = Success.new(symbolic_call: sc, return_value: [1].cycle(1))
    assert_equal <<~CODE.chomp, s.called_str
      [1].cycle(1) -> #<Enumerator: [1]:cycle(1)>[Enumerator[Integer, nil]]
    CODE
  end

  def test_success_called_str_with_enumerator_infinity
    sc = [:call, [1], :cycle, [], {}, nil]
    s = Success.new(symbolic_call: sc, return_value: [1].cycle)
    assert_equal <<~CODE.chomp, s.called_str
      [1].cycle() -> #<Enumerator: [1]:cycle>[Enumerator[Integer, bot]]
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
