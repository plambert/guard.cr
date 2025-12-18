# guard

Simple assertion macros to make code a little clearer.

Why? The static code analysis tool [ameba](https://github.com/crystal-ameba/ameba) has a rule called `Style/GuardClause`
which is described as “Check for conditionals that can be replaced with guard clauses.”
It’s a generally good idea; for example, instead of writing this:

```crystal
def my_method
  if thing = @thing
    # use thing
  end
end
```

the tool recommends this:

```crystal
def my_method
  return unless thing = @thing

  # use thing
end
```

which makes a lot of sense to me. However, at the time of this writing, the rule is
disabled by default in **ameba**. I think this is probably because having an assignment on the right of an inline conditional like that is hard to read&mdash;at least, I know
it’s hard to read for _me_.

So I wrote `guard` which you use like this:

```crystal
class MyClass
  include Guard
  def my_method
    thing = guard @thing

    # use thing
  end
end
```

That’s it—just put `guard` in front of the value in the assignment, and if the value is
`false` or `nil` then the macro will return from the method immediately.

If instead you want to raise an exception, create an Exception in a block:

```crystal
class MyClass
  include Guard
  def my_method
    thing = guard @thing { MyException.new %["oh bother," said Eeyore, "there is no thing there"] }

    # use thing
  end
end
```

And finally, if you only want to guard against `nil` values, but leave `false` alone,
then you can use the `guard!` variants.

```crystal
class MyClass
  include Guard

  @thing = false

  def my_method
    thing = guard! @thing

    # use thing, even if it’s `false`
  end
end
```

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     guard:
       github: plambert/guard.cr
   ```

2. Run `shards install`

## Usage

```crystal
require "guard"

class MyClass
  include Guard
end
```

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/plambert/guard.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Paul M. Lambert](https://github.com/plambert) - creator and maintainer
