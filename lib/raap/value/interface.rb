# frozen_string_literal: true

module RaaP
  module Value
    class Interface < BasicObject
      class << self
        def define_method_from_interface(base_class, type, size: 3)
          type = type.is_a?(::String) ? RBS.parse_type(type) : type
          unless type.instance_of?(::RBS::Types::Interface)
            ::Kernel.raise ::TypeError, "not an interface type: #{type}"
          end
          self_type = type

          # Referring to Steep
          instance_type = ::RBS::Types::ClassInstance.new(name: TypeName("::Object"), args: [], location: nil)
          class_type = ::RBS::Types::ClassSingleton.new(name: TypeName("::Object"), location: nil)

          definition = RBS.builder.build_interface(type.name.absolute!)
          definition.methods.each do |name, method|
            method_type = method.method_types.sample or ::Kernel.raise
            type_params = definition.type_params_decl.concat(method_type.type_params.drop(definition.type_params_decl.length))
            ts = TypeSubstitution.new(type_params, type.args)
            subed_method_type = ts.method_type_sub(method_type, self_type: self_type, instance_type: instance_type, class_type: class_type)

            BindCall.define_method(base_class, name) do |*_, &b|
              @fixed_return_value ||= {}
              @fixed_return_value[name] ||= if self_type == subed_method_type.type.return_type
                                              self
                                            else
                                              Type.new(subed_method_type.type.return_type).pick(size: size)
                                            end
              # @type var b: Proc?
              if b && subed_method_type.block && subed_method_type.block.type.is_a?(::RBS::Types::Function)
                @fixed_block_arguments ||= {}
                @fixed_block_arguments[name] ||= size.times.map do
                  FunctionType.new(subed_method_type.block.type)
                              .pick_arguments(size: size)
                end

                @fixed_block_arguments[name].each do |a, kw|
                  b.call(*a, **kw)
                end
              end
              @fixed_return_value[name]
            end
          end
        end

        def new(type, size: 3)
          temp_class = ::Class.new(Interface) do |c|
            define_method_from_interface(c, type, size: size)
          end
          instance = temp_class.allocate
          instance.__send__(:initialize, type, size: size)
          instance
        end
      end

      def initialize(type, size: 3)
        @type = type.is_a?(::String) ? RBS.parse_type(type) : type
        unless @type.instance_of?(::RBS::Types::Interface)
          ::Kernel.raise ::TypeError, "not an interface type: #{type}"
        end
        @definition = RBS.builder.build_interface(@type.name.absolute!)
        @size = size
      end

      def respond_to?(name, _include_all = false)
        @definition.methods.has_key?(name.to_sym)
      end

      def class
        Interface
      end

      def inspect
        "#<interface @type=`#{@type}` @methods=#{@definition.methods.keys} @size=#{@size}>"
      end
    end
  end
end
