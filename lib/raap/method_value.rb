# frozen_string_literal: true

module RaaP
  class MethodValue < Data.define(
    :receiver_value,
    :arguments,
    :method_name,
    :size
  )
    def to_symbolic_call
      args, kwargs, block = arguments
      [:call, receiver_value, method_name, args, kwargs, block]
    end

    def call_str
      r = begin
            SymbolicCaller.new(receiver_value).eval
          rescue RuntimeError, NotImplementedError
            receiver_value
          end
      "#{BindCall.inspect(r)}.#{method_name}(#{argument_str})#{block_str}"
    end

    private

    def argument_str
      args, kwargs, _ = SymbolicCaller.new(arguments).eval

      r = []
      r << args.map(&:inspect).join(', ') if !args.empty?
      r << kwargs.map { |k ,v| "#{k}: #{BindCall.inspect(v)}" }.join(', ') if !kwargs.empty?
      r.join(', ')
    end

    def block_str
      _, _, block = SymbolicCaller.new(arguments).eval
      if block
        "{ }"
      end
    end
  end
end
