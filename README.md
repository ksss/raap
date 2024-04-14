# RaaP

![Jacket](https://raw.githubusercontent.com/ksss/raap/main/public/DALL%C2%B7E%202024-03-23%2000.02.29%20-%20Imagine%20a%20scene%20where%20the%20abstract%20concepts%20of%20Ruby%20programming%20and%20property-based%20testing%20blend%20harmoniously.%20Picture%20a%20large%2C%20glowing%20ruby%20crystal%2C%20.webp)

## RBS as a Property

RaaP is a property based testing tool.

RaaP considers the RBS as a test case.

It generates random values for the method arguments for each type, and then calls the method.

The return value of the method is checked to see if it matches the type, if not, the test fails.

If you write an RBS, it becomes a test case.

## Concept

If you has next signature.

```rbs
class Foo
end

class Bar
  def initialize: (foo: Foo) -> void
  def f2s: (Float) -> String
end
```

Then, RaaP run next testing code automaticaly.

```rb
describe Bar do
  let(:foo) { Foo.new }
  let(:bar) { Bar.new(foo: foo) }

  it "#f2s" do
    100.times do |size|
      float = Random.rand * size
      expect(bar.f2s(float)).to be_a(String)
    end
  end
end
```

If you got a failure?

- Fix RBS
- Fix implementation of `Bar#f2s`

Then, you can start loop again.

Finally, you get the perfect RBS!

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add raap --require false

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install raap

## Usage

```
$ raap 'MyClass'                  # Run only RBS of MyClass
$ raap 'MyClass::*'               # Run each class under MyClass
$ raap 'MyClass.singleton_method' # Run only MyClass.singleton_method
$ raap 'MyClass#instance_method'  # Run only MyClass#instance_method
```

## Size

Random values are determined based on size.

For example, an Integer with size zero is `0` and an Array is `[]`.

RaaP, like other property-based tests, changes the size 100 times from 0 to 99 by default to generate test data.

## Symbolic call

You may possibly see the following data structure in the debug logs.

```rb
[:call, Object, :method, [], {}, nil]
```

This is a data structure of the state of the method call.

Symbolic call is a tuple beginning with `:call`, followed by the receiver, method name, positional arguments, keyword arguments, and block arguments, in that order.
And the receiver and arguments are nestable.

It is used in QuickCheck and Proper to keep as much history of method calls as possible.

## Options

### `-I PATH` or `--include PATH`

You can specify to load specify PATH as RBS.

### `--library lib`

You can specify to load RBS library

### `--require lib`

You can specify require Ruby library

### `--timeout sec`

You can specify the number of seconds to consider a test case as a timeout.

### `--size-from int`

You can specify size of start.

### `--size-to int`

You can specify size of end.

### `--size-by int`

You can specify size of step like `Integer#step: (to: Integer, by: Integer)`.

## First support is CLI

In RaaP, usage through the CLI is the primary support focus, and efforts are made to maintain compatibility. The use of the library's code (such as `RaaP::Type`) does not guarantee compatibility.

## Achievements

RaaP has already found many RBS mistakes and bug in CRuby during the development phase.

* https://github.com/ruby/rbs/pull/1704
* https://github.com/ruby/rbs/pull/1706
* https://bugs.ruby-lang.org/issues/20292
* https://github.com/ruby/rbs/pull/1768
* https://github.com/ruby/rbs/pull/1769
* https://github.com/ruby/rbs/pull/1770
* https://github.com/ruby/rbs/pull/1771
* https://github.com/ruby/rbs/pull/1779
* https://github.com/ruby/rbs/pull/1783
* https://github.com/ruby/rbs/pull/1789
* https://github.com/ruby/rbs/pull/1790
* https://github.com/ruby/rbs/pull/1793

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ksss/raap. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/ksss/raap/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Raap project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/ksss/raap/blob/main/CODE_OF_CONDUCT.md).

# TODO

- Embed testing tool.
- Implement skip solution.
- Configure by YAML?
- Support recursive type.
