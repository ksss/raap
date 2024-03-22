require 'minitest'

module RaaP
  module Minitest
    def forall(*types, size_step: 0...100)
      # @type self: Minitest::Test

      if types.length == 1 && types.first.instance_of?(String) && types.first.start_with?("(")
        # forall("(Integer) -> String") { |int| Foo.new.int2str(int) }
        type = types.first
        method_type = RaaP::MethodType.new(type)
        size_step.each do |size|
          # TODO assert_send_type
          args, kwargs, _block = method_type.pick_arguments(size: size)
          return_value = yield(*args, **kwargs)
          assert method_type.check_return(return_value), "return value: #{BindCall.inspect(return_value)}[#{BindCall.class(return_value)}] is not match with `#{method_type.rbs.type.return_type}`"
        end
      else
        # forall("Integer", "String") { |int, str| Foo.new.int_str(int, str) }
        types.map! do |type|
          case type
          in String then RaaP::Type.new(type)
          else type
          end
        end
        size_step.each do |size|
          values = types.map { |type| type.pick(size: size) }
          assert yield(*values)
        end
      end
    end
  end
end

Minitest::Test.include RaaP::Minitest
