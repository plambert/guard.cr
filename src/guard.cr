# Include this module in a class to provide `guard` macros to simplify asserting that
# values are truthy or non-nil.
#
# Use `guard` to require a value be truthy (not `false` and not `nil`). Use the
# `guard!` variant when `false` is an acceptable value.
#
module Guard
  # Guard the value in an assignment; if the value is false or nil, immediately return nil
  # from the method
  #
  # ```
  # def my_method
  #   lemur = guard @lemur # if @lemur is `false` or `nil`, we return `nil`, otherwise
  #   # we continue
  #   # ... do things with `lemur`
  # end
  # ```
  #
  macro guard(value)
    (({{ value }}) || return)
  end

  # Guard a value in an assignment; if the value is false or nil, raise the
  # yielded value
  #
  # ```
  # def my_method
  #   lemur = guard @lemur do
  #     RuntimeError.new "whoopsie!"
  #   end
  # end
  # ```
  #
  macro guard(value, &)
    ({{ value }}) || raise(yield)
  end

  # Guard the value in an assignment; if the value is nil (and only nil), immediately
  # return nil from the method
  #
  # ```
  # def my_method
  #   lemur = guard! @lemur # if @lemur is nil, we return nil, otherwise we continue
  # end
  # ```
  #
  macro guard(value)
    (({{ value }}).tap { |val| return if val.nil? })
  end

  # Guard a value in an assignment; if the value is nil (and only nil), raise the
  # yielded exception
  #
  # ```
  # def my_method
  #   lemur = guard! @lemur do
  #     RuntimeError.new "whoopsie!"
  #   end
  # end
  # ```
  #
  macro guard!(value, &)
    (({{ value }}).tap { |val| raise(yield) if val.nil? })
  end
end
