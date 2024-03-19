module RaaP
  module Value
    class Variable < BasicObject
      attr_reader :type

      def initialize(type)
        @type = type
      end

      def inspect = "#<var #{type}>"
      def class = Variable
    end
  end
end
