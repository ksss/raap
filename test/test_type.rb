# frozen_string_literal: true

require "test_helper"

class TestType < Minitest::Test
  Type = RaaP::Type

  def test_pick_basic_class
    assert Type.new("BasicObject").pick
    assert Type.new("Object").pick.instance_of?(Object)
    assert Type.new("Integer").pick.instance_of?(Integer)
    assert Type.new("Float").pick.instance_of?(Float)
    assert Type.new("Rational").pick.instance_of?(Rational)
    assert Type.new("Complex").pick.instance_of?(Complex)
    assert Type.new("String").pick.instance_of?(String)
    assert Type.new("Symbol").pick.instance_of?(Symbol)
    assert Type.new("Binding").pick.instance_of?(Binding)
    assert Type.new("Class").pick.instance_of?(Class)
    assert Type.new("Enumerator").pick.instance_of?(Enumerator)
    assert Type.new("Method").pick.instance_of?(Method)
    assert Type.new("Module").pick.instance_of?(Module)
    assert Type.new("Proc").pick.instance_of?(Proc)
    assert Type.new("Regexp").pick.instance_of?(Regexp)
    assert Type.new("Struct").pick.kind_of?(Struct)
    assert Type.new("Time").pick.instance_of?(Time)
    assert Type.new("UnboundMethod").pick.instance_of?(UnboundMethod)
    assert Type.new("Encoding").pick.instance_of?(Encoding)
  end

  def test_bool
    come_true = false
    come_false = false
    forall("bool", size_step: 0...100) do |bool|
      come_true = true if bool.equal?(true)
      come_false = true if bool.equal?(false)
      true
    end
    assert come_true
    assert come_false
  end

  def test_numeric
    forall("Numeric") do |numeric|
      numeric.kind_of?(Numeric)
    end
  end

  def test_pick_array_with_range
    type = Type.new("Array[Integer]", range: 10..)
    forall(type) do |array|
      assert array.instance_of?(Array)
      assert array.length >= 10
      array.all? { |i| i.instance_of?(Integer) }
    end
  end

  def test_pick_hash
    forall("Hash[Symbol, Integer]") do |hash|
      assert hash.instance_of?(Hash)
      assert hash.keys.all? { |key| key.instance_of?(Symbol) }
      assert hash.values.all? { |value| value.instance_of?(Integer) }
    end
  end

  def test_pick_range
    forall("Range[Integer]") do |range|
      assert range.instance_of?(Range)
      assert range.begin.instance_of?(Integer)
      assert range.end.instance_of?(Integer)
    end
  end

  # def test_set
  #   forall("Set[Symbol]") do |set|
  #     set.each do |sym|
  #       assert sym.instance_of?(Symbol)
  #     end
  #     assert set.kind_of?(Set)
  #   end
  # end

  def test_bottom
    assert_equal ["RaaP::Value::Bottom.new()"], Type.new("bot").to_symbolic_caller.to_lines
  end

  def test_interface
    a = []
    Type.new("_Each[Integer]").pick(size: 3).each do |i|
      a << i
    end
    assert 3, a.length
    assert a.all? { |i| i.is_a?(Integer) }

    assert_equal ["RaaP::Value::Interface.new('_Each[Integer]', size: 3)"],
                 Type.new("_Each[Integer]").to_symbolic_caller(size: 3).to_lines
  end

  def test_intersection
    o = Type.new("_Each[Integer] & Object").pick
    a = []
    o.each do |i|
      a << i
    end
    assert a.all? { |i| i.instance_of?(Integer) }

    assert_equal ["RaaP::Value::Intersection.new('_Each[Integer] & Object', size: 3)"],
                 Type.new("_Each[Integer] & Object").to_symbolic_caller(size: 3).to_lines
  end

  def test_module
    assert Kernel === Type.new("Kernel").pick
    assert Enumerable === Type.new("Enumerable").pick
    assert Comparable === Type.new("Comparable").pick
    assert_equal ["RaaP::Value::Module.new('Comparable')"],
                 Type.new("Comparable").to_symbolic_caller.to_lines
  end

  def test_variable
    t = ::RBS::Types::Variable.new(name: :T, location: nil)
    assert_equal ["RaaP::Value::Variable.new(:T)"], Type.new(t).to_symbolic_caller.to_lines
  end

  def test_top
    assert_equal ["RaaP::Value::Top.new()"], Type.new("top").to_symbolic_caller.to_lines
  end

  def test_void
    assert_equal ["RaaP::Value::Void.new()"], Type.new("void").to_symbolic_caller.to_lines
  end

  def test_union
    forall("Test::A | Array[Test::B] | Hash[Symbol, String | Test::C]") do |o|
      true
    end
  end

  def test_array_with_union
    forall("Array[Test::A | Test::B]") do |array|
      assert array.instance_of?(Array)
      if array.length > 0
        assert array.any? { |v| v.instance_of?(Test::A) || v.instance_of?(Test::B) }
      end
      true
    end
  end

  def test_hash_with_union
    forall("Hash[Symbol, Test::A | Test::B]") do |hash|
      assert hash.instance_of?(Hash)
      if hash.length > 0
        assert hash.values.any? { |v| v.instance_of?(Test::A) || v.instance_of?(Test::B) }
      end
      true
    end
  end

  def test_tuple
    int, lit, str = Type.new("[Integer, :lit, String]").pick
    assert int.instance_of?(Integer)
    assert lit == :lit
    assert str.instance_of?(String)
  end

  def test_singleton
    assert Integer == Type.new("singleton(Integer)").pick
  end

  def test_record
    record = Type.new("{ foo: Integer, bar: String }").pick
    assert record.instance_of?(Hash)
    assert record[:foo].instance_of?(Integer)
    assert record[:bar].instance_of?(String)
  end

  def test_proc
    assert :ok == Type.new("^() -> :ok").pick.call
  end

  def test_litelal
    assert_equal 42, Type.new("42").pick
    assert_equal :ok, Type.new(":ok").pick
    assert_equal "cool", Type.new('"cool"').pick
    assert_nil Type.new('nil').pick
    assert_equal true, Type.new('true').pick
    assert_equal false, Type.new('false').pick
  end

  def test_top
    assert RaaP::BindCall.instance_of?(Type.new("top").pick, RaaP::Value::Top)
  end

  # TODO
  # def test_nested
  #   assert_instance_of Test::Nested, Type.new("Test::Nested").pick
  # end
end
