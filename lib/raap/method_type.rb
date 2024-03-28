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
      ts = TypeSubstitution.new(type_params_decl + rbs.type_params, type_args)

      @rbs = ts.method_type_sub(rbs, self_type:, instance_type:, class_type:)
      @fun_type = FunctionType.new(@rbs.type)
    end

    def pick_arguments(size: 10)
      SymbolicCaller.new(arguments_to_symbolic_call(size:)).eval
    end

    def arguments_to_symbolic_call(size: 10)
      args, kwargs = @fun_type.arguments_to_symbolic_call(size:)
      block = block_to_symbolic_call(size:)

      [args, kwargs, block]
    end

    def pick_block(size: 10)
      SymbolicCaller.new(block_to_symbolic_call(size:)).eval
    end

    def block_to_symbolic_call(size: 10)
      block = @rbs.block
      return nil if block.nil?
      return nil if (block.required == false) && [true, false].sample

      Proc.new { Type.new(block.type.return_type).to_symbolic_call(size:) }
    end

    def check_return(return_value)
      untyped = __skip__ = nil
      type_check = ::RBS::Test::TypeCheck.new(
        self_class: untyped,     # cannot support `self`
        instance_class: untyped, # cannot support `instance`
        class_class: untyped,    # cannot support `class`
        builder: RBS.builder,
        sample_size: 100,
        unchecked_classes: []
      )
      type_check.value(return_value, rbs.type.return_type)
    end
  end
end
