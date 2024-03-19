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

    def pick_arguments(size: 10, eval: true)
      args, kwargs = @fun_type.pick_arguments(size: size, eval:)
      block = pick_block(size: size, eval:)

      [args, kwargs, block]
    end

    def pick_block(size: 10, eval: true)
      block = @rbs.block
      return nil if block.nil?
      return nil if (block.required == false) && [true, false].sample

      Proc.new { Type.new(block.type.return_type).pick(size:, eval:) }
    end
  end
end
