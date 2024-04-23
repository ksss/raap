# frozen_string_literal: true

module RaaP
  module Value
    class Bottom < BasicObject
      def inspect = "#<bot>"
      def class = Bottom
    end
  end
end
