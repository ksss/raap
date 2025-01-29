# frozen_string_literal: true

module RaaP
  class MethodType
    attr_reader :rbs

    def initialize(method, type_params_decl: [], type_args: [], self_type: nil, instance_type: nil, class_type: nil)
      rbs =
        case method
        when ""
          raise ArgumentError, "method type is empty"
        when String
          ::RBS::Parser.parse_method_type(method, require_eof: true) or raise
        when ::RBS::MethodType
          method
        else
          raise "bad method #{method}"
        end

      params = (type_params_decl + rbs.type_params).uniq
      ts = TypeSubstitution.new(params, type_args)
      @rbs = ts.method_type_sub(rbs, self_type: self_type, instance_type: instance_type, class_type: class_type)
      function_or_untypedfunction = __skip__ = @rbs.type
      @fun_type = FunctionType.new(function_or_untypedfunction)
      @type_check = ::RBS::Test::TypeCheck.new(
        self_class: (_ = self_type),
        instance_class: (_ = instance_type),
        class_class: (_ = class_type),
        builder: RBS.builder,
        sample_size: 100,
        unchecked_classes: []
      )
    end

    def pick_arguments(size: 10)
      SymbolicCaller.new(arguments_to_symbolic_call(size: size)).eval
    end

    def arguments_to_symbolic_call(size: 10)
      args, kwargs = @fun_type.arguments_to_symbolic_call(size: size)
      block = pick_block(size: size)

      [args, kwargs, block]
    end

    def pick_block(size: 10)
      block = @rbs.block
      return nil if block.nil?
      return nil if (block.required == false) && [true, false].sample

      args_name = [] #: Array[String]
      args_source = [] #: Array[String]
      resource = [*'a'..'z']
      case fun = block.type
      when ::RBS::Types::Function
        # FIXME: Support keyword types
        fun.required_positionals.each do
          resource.shift.tap do |name|
            args_name << name
            args_source << name
          end
        end
        fun.optional_positionals.each do |param|
          resource.shift.tap do |name|
            default = Type.new(param.type).pick(size: size)
            args_name << name
            # FIXME: Support any object
            args_source << "#{name} = #{default.inspect}"
          end
        end
        fun.rest_positionals&.yield_self do |_|
          resource.shift.tap do |name|
            args_name << "*#{name}"
            args_source << "*#{name}"
          end
        end
        fun.trailing_positionals.each do
          resource.shift.tap do |name|
            args_name << name
            args_source << name
          end
        end
      end
      # Hack: Use local variable in eval
      fixed_return_value = Type.new(block.type.return_type).pick(size: size)
      _ = fixed_return_value
      type_check = @type_check
      _ = type_check
      eval(<<~RUBY) # rubocop:disable Security/Eval
        -> (#{args_source.join(', ')}) do
          i = 0
          type_check.zip_args([#{args_name.join(', ')}], block.type) do |val, param|
            unless type_check.value(val, param.type)
              raise TypeError, "block argument type mismatch: expected `(\#{fun.param_to_s})`, got \#{BindCall.inspect([#{args_name.join(', ')}])}"
            end

            Coverage.log_with_type("block_param_\#{i}", param.type)
            i += 1
          end
          Coverage.log_with_type("block_return", block.type.return_type)
          fixed_return_value
        end
      RUBY
    end

    def check_return(return_value)
      @type_check.value(return_value, rbs.type.return_type)
    end
  end
end
