module RaaP
  module Value
    # FIXME: consider self_types
    class Module < BasicObject
      attr_reader :type

      def initialize(type)
        @type = type
        const = ::Object.const_get(type.name.absolute!.to_s)
        BindCall.extend(self, const)
      end

      def inspect = "#<module #{@type}>"
      def class = Value::Module
    end
  end
end
