require 'test_helper'

class TestInterface < Minitest::Test
  Interface = RaaP::Value::Interface

  def test_simple
    assert RaaP::BindCall.instance_of?(Interface.new("Test::_Interface").void, RaaP::Value::Void)
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
