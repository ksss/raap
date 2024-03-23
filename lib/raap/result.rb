# frozen_string_literal: true

module RaaP
  module Result
    module CalledStr
      def called_str
        "#{method_value.call_str} -> #{return_value.inspect}[#{return_value.class}]"
      end
    end

    Success = Data.define(:method_value, :return_value)
    Success.include CalledStr
    Failure = Data.define(:method_value, :return_value, :symbolic_call, :exception) do
      def initialize(exception: nil, **)
        super
      end
    end
    Failure.include CalledStr
    Skip = Data.define(:method_value, :exception)
    Exception = Data.define(:method_value, :exception)
  end
end
