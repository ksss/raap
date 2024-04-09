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
end
