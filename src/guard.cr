# Include this module in a class to provide `guard` macros to simplify asserting that
# values are truthy or non-nil.
#
# Use `guard` to require a value be truthy (not `false` and not `nil`). Use the
# `guard!` variant when `false` is an acceptable value.
#
module Guard
  # Guard the value in an assignment. If the value is false or nil, either raise the
  # exception returned by the block, or if no block is given, immediately return from
  # the method.
  #
  # ```
  # def my_method
  #   lemur = guard @lemur # if @lemur is `false` or `nil`, we return `nil`, otherwise
  #   # we continue
  #   # ... do things with `lemur`
  # end
  # ```
  #
  macro guard(expr, &block)
    {% if block %}
      begin
        %value = ({{ expr }})
        raise({{ yield }}) unless %value
        %value
      end
    {% else %}
      (({{ expr }}) || return)
    {% end %}
    # { % debug %}
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
  macro guard!(expr, &block)
    {% if block %}
      {% if expr.is_a?(Assign) %}
        raise({{ yield }}) if ({{ expr }}).nil?
      {% else %}
        begin
          %value = ({{ expr }})
          raise({{ yield }}) if %value.nil?
          %value
        end
      {% end %}
    {% else %}
      {% if expr.is_a?(Assign) %}
        return if ({{ expr }}).nil?
      {% else %}
        begin
          %value = ({{ expr }})
          return if %value.nil?
          %value
        end
      {% end %}
    {% end %}
    # { % debug %}
  end

  class Exception < ::Exception; end
end
