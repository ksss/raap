# frozen_string_literal: true

module RaaP
  module Value
    class Intersection < BasicObject
      def initialize(type, size:)
        @type = type
        @children = type.types.map { |t| Type.new(t).pick(size: size) }
        @size = size
      end

      def inspect
        "#<intersection @type=#{@type.to_s.inspect} @size=#{@size.inspect}>"
      end

      def class
        Intersection
      end

      def method_missing(name, *args, **kwargs, &block)
        @children.each do |child|
          if BindCall.respond_to?(child, name)
            return child.__send__(name, *args, **kwargs, &block)
          end
        end
      end

      def respond_to?(...)
        @children.any? do |type|
          BindCall.respond_to?(type, ...)
        end
      end
    end
  end
end
