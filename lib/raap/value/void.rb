module RaaP
  module Value
    class Void < BasicObject
      def inspect = "#<void>"
      def class = Void
    end
  end
end
