# frozen_string_literal: true

module RaaP
  module Value
    class Variable
      attr_reader :type

      def initialize(type)
        @type =
          if type.respond_to?(:to_sym)
            # @type var type: String | Symbol
            ::RBS::Types::Variable.new(name: type.to_sym, location: nil)
          else
            type
          end
        unless @type.instance_of?(::RBS::Types::Variable)
          ::Kernel.raise ::TypeError, "not a variable type: #{@type}"
        end
      end

      def inspect = "#<var #{type}>"
      def class = Variable
    end
  end
end
