# frozen_string_literal: true

require "test_helper"

class TestValue < Minitest::Test
  include RaaP::Value

  def test_bottom
    assert_equal "#<bot>", Bottom.new.inspect
    assert_equal Bottom, Bottom.new.class
  end

  def test_interface
    assert RaaP::BindCall.instance_of?(Interface.new("Test::_Interface").void, RaaP::Value::Void)

    assert_raises(TypeError) do
      Interface.new("bool")
    end
  end

  def test_interface_with_self_type
    [Integer, Float, String, Symbol].each do |klass|
      interface = Interface.new("Test::_Interface", self_type: klass.name)
      first_return = interface.selfie
      assert_instance_of klass, first_return
      assert_equal first_return, interface.selfie
    end

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

  def test_module
    mod = Module.new("Comparable")
    assert mod.object_id
    assert_respond_to mod, :<=>

    assert_raises(TypeError) do
      Module.new("bool")
    end
  end

  def test_top
    assert_equal "#<top>", Top.new.inspect
    assert_equal Top, Top.new.class
  end

  def test_variable
    assert_equal "#<var T>", Variable.new("T").inspect
    assert_equal Variable, Variable.new("T").class
    assert_equal ::RBS::Types::Variable.new(name: :T, location: nil), Variable.new(:T).type
  end

  def test_void
    assert_equal "#<void>", Void.new.inspect
    assert_equal Void, Void.new.class
  end
end
