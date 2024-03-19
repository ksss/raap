require 'test_helper'

class TestInterface < Minitest::Test
  Interface = RaaP::Value::Interface

  def test_simple
    assert_equal :raap_void, Interface.new("Test::_Interface").void
  end

  def test_with_self_type
    [Integer, Float, String, Symbol].each do |klass|
      interface = Interface.new("Test::_Interface", self_type: klass.name)
      first_return = interface.selfie
      assert_instance_of klass, first_return
      assert_equal first_return, interface.selfie
    end
  end
end
