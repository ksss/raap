# frozen_string_literal: true

require "test_helper"

class TestResult < Minitest::Test
  include RaaP::Result

  class ReturnType < Data.define(:return_value)
    include RaaP::Result::ReturnValueWithType
  end

  def test_return_value_with_type_nil
    assert_equal "nil", ReturnType.new(nil).return_value_with_type
  end

  def test_return_value_with_type_bool
    assert_equal "true[bool]", ReturnType.new(true).return_value_with_type
  end

  def test_return_value_with_type_array_empty
    assert_equal "[][Array[untyped]]", ReturnType.new([]).return_value_with_type
  end

  def test_return_value_with_type_array_integer
    assert_equal "[1, 2, 3][Array[Integer]]", ReturnType.new([1, 2, 3]).return_value_with_type
  end

  def test_return_value_with_type_hash_empty
    assert_equal "{}[Hash[untyped, untyped]]", ReturnType.new({}).return_value_with_type
  end

  def test_return_value_with_type_hash_symbol_integer
    assert_equal "{:a => 1}[Hash[Symbol, Integer]]", ReturnType.new({ a: 1 }).return_value_with_type
  end

  def test_return_value_with_type_enumerator_empty
    assert_equal "#<Enumerator: []:each>[Enumerator[untyped, Array[untyped]]]", ReturnType.new([].each).return_value_with_type
  end

  def test_return_value_with_type_enumerator_limited
    assert_equal "#<Enumerator: [1]:cycle(1)>[Enumerator[Integer, nil]]", ReturnType.new([1].cycle(1)).return_value_with_type
  end

  def test_return_value_with_type_enumerator_infinity
    assert_equal "#<Enumerator: [1]:cycle>[Enumerator[Integer, bot]]", ReturnType.new([1].cycle).return_value_with_type
  end

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
