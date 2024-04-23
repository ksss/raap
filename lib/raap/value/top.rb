# frozen_string_literal: true

module RaaP
  module Value
    class Top < BasicObject
      def inspect = "#<top>"
      def class = Top
    end
  end
end
