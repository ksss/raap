module Test
  class Property
    def method_property1
      case Random.rand(3)
      when 0
        true
      when 1
        false
      when 2
        raise NotImplementedError
      else
        raise
      end
    end

    # It testing the error indication by making a mistake on purpose.
    def integer_only = 1
    alias alias integer_only

    def int_to_int(int)
      int
    end
  end

  class Sleep
    def sleep
      Kernel.sleep
    end
  end

  class List
    attr_reader :head
    attr_reader :tail

    def initialize(head: nil, tail: nil)
      @head = head
      @tail = tail
    end

    def add(elem)
      List.new(head: elem, tail: self)
    end

    def each(&block)
      return self if @tail.nil?

      yield @head
      @tail.each(&block)
    end

    def to_a
      a = []
      each { |e| a << e }
      a
    end

    def inspect
      "Test::List{#{to_a.join(', ')}}"
    end
  end

  class CSelf
    def self.meth = self
    def meth = self
    def self.arg(a) = a
    def arg(a) = a
  end

  class CInstance
    def self.meth = new
    def meth = self
    def self.arg(a) = a
    def arg(a) = a
  end

  class CClass
    def self.meth = CClass
    def meth = CClass
    def self.arg(a) = a
    def arg(a) = a
  end

  module MSelf
    def self.meth = self
    def meth = self
    def self.arg(a) = a
    def arg(a) = a
  end

  module MInstance
    def self.meth = CMInstance.new
    def meth = self
    def self.arg(a) = a
    def arg(a) = a
  end

  module MClass
    def self.meth = MClass
    def meth = MClass
    def self.arg(a) = a
    def arg(a) = a
  end

  class CMSelf
    include MSelf
  end

  class CMInstance
    include MInstance
  end

  class CMClass
    include MClass
  end

  class Interface
    def i(interface)
      interface.void
      interface.selfie
      interface.instance
      interface.klass
    end
  end

  class Bottom
    def b = raise
  end

  class A
  end

  class B
  end

  class C
    def initialize(a: nil, b: nil)
    end

    def run
      Random.rand(5)
    end
  end

  class Value
    def top(t); end
    def bottom(b); end
  end

  class Accessibility
    public def public_method; end
    private def private_method; end
  end

  class Meth
    def arg1(int)
      int.to_s
    end

    def sym(_sym)
      self
    end
  end

  class Nested
    def initialize(t)
      @t = t
    end

    def nest(_nt)
      self
    end
  end

  module ValueModule
  end

  module ValueModuleWithBasicObject
  end

  module ValueModuleWithInterface
    def each_t(&block)
      each(&block)
    end

    def too_f
      to_f
    end
  end

  class BlockReturnVoid
    def initialize(&block)
      @block = block
    end

    def call
      @block.call
    end
  end

  class BlockReturnLiteral
    def initialize(&block)
      @block = block
    end

    def call
      @block.call
    end
  end

  class SkipIfIncludeUntyped
    def u(&block)
    end
  end

  class SkipPrefix
    def should_not_skip = :ok
    def should_skip = raise("Should not run!")
  end

  class TypeErrorIsFail
    def type_error
      raise TypeError
    end
  end

  class TestException < Exception # rubocop:disable Lint/InheritException
  end

  class ExceptionWithBot
    def exception
      raise TestException
    end
  end

  class Coverage
    attr_reader :a

    def initialize
      @a = 1
    end

    def one_line(int, sym) = [int, sym]
    def two_lines(a:, b: nil, **rk) = a
    def three_lines = [:a, :c].sample
    def block = yield(1)
    def all_variables(*) = 1
    def singleton = Test::Coverage
  end

  class BlockArgsCheck
    def different_type
      yield 'zzz'
    end
  end

  class NoKey
    def a(**nil) = nil
    def b(*, **nil) = nil
  end

  class Set
    def foo(a) = 123
    def bar(a) = 456
  end

  class ImplicitlyReturnsNil
    def overload = [:overload, nil].sample
    def method = [:method, nil].sample
    def both = [:both, nil].sample
  end
end
