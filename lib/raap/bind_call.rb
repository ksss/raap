module RaaP
  module BindCall
    class << self
      def define_singleton_method(...) = ::Object.instance_method(:define_singleton_method).bind_call(...)
      def respond_to?(...) = ::Kernel.instance_method(:respond_to?).bind_call(...)
      def instance_of?(...) = ::Kernel.instance_method(:instance_of?).bind_call(...)
      def is_a?(...) = ::Kernel.instance_method(:is_a?).bind_call(...)
      def extend(...) = ::Kernel.instance_method(:extend).bind_call(...)
      def name(...) = ::Module.instance_method(:name).bind_call(...)
      def to_s(...) = ::Kernel.instance_method(:to_s).bind_call(...)

      def class(obj)
        if respond_to?(obj, :class)
          obj.class
        else
          ::Kernel.instance_method(:class).bind_call(obj)
        end
      end

      def inspect(obj)
        if respond_to?(obj, :inspect)
          obj.inspect
        else
          ::Kernel.instance_method(:inspect).bind_call(obj)
        end
      end
    end
  end
end
