# frozen_string_literal: true

module RaaP
  module Value
    class Interface < BasicObject
      def initialize(type, size: 3, self_type: nil, instance_type: nil, class_type: nil)
        @type = type.is_a?(::String) ? RBS.parse_type(type) : type
        unless @type.instance_of?(::RBS::Types::Interface)
          ::Kernel.raise ::TypeError, "not an interface type: #{@type}"
        end
        @size = size

        definition = RBS.builder.build_interface(@type.name.absolute!)
        definition.methods.each do |name, method|
          method_type = method.method_types.sample or Kernel.raise
          type_params = definition.type_params_decl.concat(method_type.type_params.drop(definition.type_params_decl.length))
          ts = TypeSubstitution.new(type_params, @type.args)

          subed_method_type = ts.method_type_sub(method_type, self_type:, instance_type:, class_type:)

          BindCall.define_singleton_method(self, name) do |*_, &b|
            # @type var b: Proc?
            @fixed_return_value ||= Type.new(subed_method_type.type.return_type).pick(size:)
            if subed_method_type.block
              @fixed_block_arguments ||= size.times.map do
                fun_type = FunctionType.new(subed_method_type.block.type)
                fun_type.pick_arguments(size:)
              end
            else
              @fixed_block_arguments = []
            end
            if b
              unless subed_method_type.block
                Kernel.raise "block of `#{@type.name}##{name}` was called. But block signature not defined."
              end
              @fixed_block_arguments.each do |a, kw|
                b.call(*a, **kw)
              end
            end
            @fixed_return_value
          end
        end
      end

      def class
        Interface
      end

      def inspect
        "#<interface @type=#{@type.to_s} @methods=#{RBS.builder.build_interface(@type.name.absolute!).methods.keys} @size=#{@size}>"
      end
    end
  end
end
