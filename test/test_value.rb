# frozen_string_literal: true

require "test_helper"

class TestValue < Minitest::Test
  include RaaP::Value

  def test_bottom
    assert_equal "#<bot>", Bottom.new.inspect
    assert_equal Bottom, Bottom.new.class
  end

  def test_interface
    interface = Interface.new("Test::_Interface")
    assert interface.respond_to?(:lit)
    assert interface.inspect
    assert_equal RaaP::Value::Interface, interface.class

    assert_equal :sym, interface.lit
    assert RaaP::BindCall.instance_of?(interface.void, RaaP::Value::Void)
    assert RaaP::BindCall.is_a?(interface.selfie, RaaP::Value::Interface)
    assert RaaP::BindCall.instance_of?(interface.instance, Object)
    assert RaaP::BindCall.instance_of?(interface.klass, Class)
    # check cache
    assert_equal :sym, interface.lit
    assert RaaP::BindCall.instance_of?(interface.void, RaaP::Value::Void)
    assert RaaP::BindCall.is_a?(interface.selfie, RaaP::Value::Interface)
    assert RaaP::BindCall.instance_of?(interface.instance, Object)
    assert RaaP::BindCall.instance_of?(interface.klass, Class)

    assert_raises(TypeError) do
      Interface.new("bool")
    end
  end

  def test_intersection
    intersection = Intersection.new("Object & _Each[Integer]", size: 10)
    assert intersection.object_id
    intersection.each do |int|
      assert_instance_of Integer, int
    end

    assert_raises(TypeError) do
      Intersection.new("bool")
    end

    refute intersection.respond_to?(:not_defined)
    assert_raises(NoMethodError) do
      intersection.not_defined
    end
  end

  def test_math_acos
    intersection = Intersection.new("Numeric & _ToF", size: 0)
    # Math methods argument must be Numeric instance
    assert Math.sin(intersection)
    assert Math.cos(intersection)
    assert Math.tan(intersection)
  end

  def test_module
    assert_raises(TypeError) do
      Module.new("bool")
    end

    mod = Module.new("::Test::ValueModule")
    assert mod.object_id
    assert_raises(NoMethodError) do
      mod.not_defined
    end
  end

  def test_module_with_self_type
    mod = Module.new("::Test::ValueModuleWithBasicObject")
    assert mod.__id__
    assert_raises(NoMethodError) do
      mod.object_id
    end
  end

  def test_module_with_interface_and_no_args
    mod = Module.new("::Test::ValueModuleWithInterface", size: 10)
    count = 0
    mod.each_t do
      count += 1
    end
    assert_equal 10, count
  end

  def test_module_with_interface_and_args
    mod = Module.new("::Test::ValueModuleWithInterface[Integer]", size: 10)
    count = 0
    mod.each_t do |int|
      count += 1
      assert_instance_of Integer, int
    end
    assert_equal 10, count

    assert_instance_of Float, mod.too_f
  end

  def test_top
    assert_equal "#<top>", Top.new.inspect
    assert_equal Top, Top.new.class
  end

  def test_variable
    assert_equal "#<var T>", Variable.new("T").inspect
    assert_equal Variable, Variable.new("T").class
    assert_equal ::RBS::Types::Variable.new(name: :T, location: nil), Variable.new(:T).type
    assert_raises TypeError do
      Variable.new(1)
    end
  end

  def test_void
    assert_equal "#<void>", Void.new.inspect
    assert_equal Void, Void.new.class
  end
end
