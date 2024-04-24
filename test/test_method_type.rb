# frozen_string_literal: true

require "test_helper"

class TestMethodType < Minitest::Test
  MethodType = RaaP::MethodType
  Type = RaaP::Type

  def test_pick_arguments_with_empty
    assert MethodType.new("() -> void").pick_arguments == [[], {}, nil]
  end

  def test_pick_arguments_with_required_positionals
    args, kwargs, block = MethodType.new("(Integer, String) -> void").pick_arguments
    assert args.length == 2
    assert args[0].instance_of?(Integer)
    assert args[1].instance_of?(String)
    assert kwargs == {}
    assert block.nil?
  end

  def test_pick_arguments_with_optional_positionals
    forall("(?Integer, ?String, ?Symbol) -> void") do |int, str, sym|
      assert_instance_of(Integer, int) if int
      assert_instance_of(String, str) if str
      assert_instance_of(Symbol, sym) if sym
    end
  end

  def test_to_symbolic_call
    args, _, _ = MethodType.new("(Array[Test::C]) -> void").arguments_to_symbolic_call(size: 0)
    assert_equal [[]], args
  end

  def test_minitest
    forall("(Integer, sym: Symbol) -> String") do |int, sym:|
      Test::Meth.new.sym(sym)
      Test::Meth.new.arg1(int)
    end
  end

  def test_minitest_fail
    begin
      forall("(Integer, sym: Symbol) -> Integer") do |int, sym:|
        Test::Meth.new.sym(sym)
        Test::Meth.new.arg1(int)
      end
    rescue Minitest::Assertion => e
      assert e
    end
  end

  def test_pick_arguments_with_rest_positionals_and_trailings
    10.times do |size|
      args, _, _ = MethodType.new("(*Integer, String) -> void").pick_arguments(size: size)
      assert args.length > 0
      trailing = args.pop
      assert(args.all? { |int| int.instance_of?(Integer) })
      assert trailing.instance_of?(String)
    end
  end

  def test_pick_arguments_with_required_keywords
    args, kwargs, block = MethodType.new("(foo: Integer, bar: String) -> void").pick_arguments
    assert args == []
    assert kwargs.length == 2
    assert kwargs[:foo].instance_of?(Integer)
    assert kwargs[:bar].instance_of?(String)
    assert block.nil?
  end

  def test_pick_arguments_with_rest_keywords
    presents = []
    10.times do |size|
      _, kwargs, _ = MethodType.new("(foo: Integer, **String) -> void").pick_arguments(size: size)
      assert kwargs.length > 0
      assert kwargs[:foo].instance_of?(Integer)
      rest = kwargs.except(:foo)
      presents << !rest.empty?
      assert(rest.keys.all? { |key| key.instance_of?(Symbol) })
      assert(rest.values.all? { |value| value.instance_of?(String) })
    end
    assert presents.any?
  end

  def test_pick_arguments_with_block
    args, kwargs, block = MethodType.new("() { (Integer) -> String } -> void").pick_arguments
    assert args == []
    assert kwargs == {}
    assert block.instance_of?(Proc)
    assert block.call.instance_of?(String)
  end

  def test_pick_arguments_with_type_params
    args, _, _ = MethodType.new("[T] (T) -> T").pick_arguments
    assert args.length == 1
    assert_raises(NoMethodError) { args.first.to_s }
  end

  def test_pick_arguments_with_type_params_and_bound
    args, _, _ = MethodType.new("[T < Integer] (T) -> T").pick_arguments
    assert args.length == 1
    assert args[0].instance_of?(Integer)
  end

  def test_pick_arguments_with_type_params_and_bound_interface
    args, _, _ = MethodType.new("[T < _Each[Integer]] (T) -> T").pick_arguments
    assert args.length == 1
    assert RaaP::Value::Interface === args[0]
    args[0].each do |int|
      assert int.instance_of?(Integer)
    end
  end

  def test_pick_arguments_with_self
    assert_raises do
      MethodType.new("(self) -> void").pick_arguments
    end

    args, _, _ = MethodType.new("(self) -> void", self_type: "Integer").pick_arguments
    assert args[0].instance_of?(Integer)

    block = MethodType.new("() { () -> self } -> void", self_type: "Integer").pick_block
    assert block.call.instance_of?(Integer)
  end
end
