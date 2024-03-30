# frozen_string_literal: true

module RaaP
  module Result
    module CalledStr
      def called_str
        scr = SymbolicCaller.new(symbolic_call)
        return_type =
          case return_value
          when nil then ''
          when true, false then 'bool'
          else
            BindCall.class(return_value)
          end
        "#{scr.call_str} -> #{BindCall.inspect(return_value)}[#{return_type}]"
      end
    end

    Success = Data.define(:symbolic_call, :return_value)
    Success.include CalledStr
    Failure = Data.define(:symbolic_call, :return_value, :exception) do
      def initialize(exception: nil, **)
        super
      end
    end
    Failure.include CalledStr
    Skip = Data.define(:symbolic_call, :exception)
    Exception = Data.define(:symbolic_call, :exception)
  end
end
