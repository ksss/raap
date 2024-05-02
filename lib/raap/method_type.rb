# frozen_string_literal: true

module RaaP
  class MethodType
    attr_reader :rbs, :original_rbs

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

      @original_rbs = rbs
      @rbs = ts.method_type_sub(rbs, self_type: self_type, instance_type: instance_type, class_type: class_type)
      function_or_untypedfunction = __skip__ = @rbs.type
      @fun_type = FunctionType.new(function_or_untypedfunction)
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

      block.type.each_param do |param|
        if param.location
          Coverage.log(name: param.location.buffer.name, locs: [
            param.location.start_loc,
            param.location.end_loc
          ])
        end
      end
      fixed_return_value = Type.new(block.type.return_type).pick(size: size)
      Proc.new do
        if block.type.return_type.location
          Coverage.log(name: block.type.return_type.location.buffer.name, locs: [
            block.type.return_type.location.start_loc,
            block.type.return_type.location.end_loc
          ])
        end
        fixed_return_value
      end
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
