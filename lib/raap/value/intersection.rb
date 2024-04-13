# frozen_string_literal: true

module RaaP
  module Value
    class Intersection < BasicObject
      def initialize(type, size: 3)
        @type = type.is_a?(::String) ? RBS.parse_type(type) : type
        unless @type.instance_of?(::RBS::Types::Intersection)
          ::Kernel.raise ::TypeError, "not an intersection type: #{@type}"
        end
        @children = @type.types.map { |t| Type.new(t).pick(size:) }
        @size = size
      end

      def inspect
        "#<intersection @type.to_s=#{@type.to_s.inspect} @size=#{@size.inspect}>"
      end

      def class
        Intersection
      end

      def method_missing(name, *args, **kwargs, &block)
        if respond_to?(name)
          @children.each do |child|
            if BindCall.respond_to?(child, name)
              return child.__send__(name, *args, **kwargs, &block)
            end
          end
          ::Kernel.raise
        else
          super
        end
      end

      def respond_to?(name, include_all = false)
        @children.any? do |child|
          if BindCall.instance_of?(child, ::BasicObject)
            BindCall.respond_to?(child, name, include_all)
          else
            child.respond_to?(name, include_all)
          end
        end
      end
    end
  end
end
