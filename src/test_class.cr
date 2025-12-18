require "./guard"

class TestClass
  include Guard

  INTEGER_VALUE = 7
  @int : Int32? = INTEGER_VALUE
  @nil : Int32? = nil
  @false : Int32 | Bool | Nil = false

  def test_int_value
    copy = guard @int
    copy
  end

  def test_nil_value
    copy = guard @nil
    copy
  end

  def test_false_value
    copy = guard @false
    copy
  end

  def test_int_assign
    guard copy = @int
    copy
  end

  def test_nil_assign
    guard copy = @nil
    copy
  end

  def test_false_assign
    guard copy = @false
    copy
  end

  def test_int_value_exception
    copy = guard @int { ::TestClass::Error.new }
    copy
  end

  def test_nil_value_exception
    copy = guard @nil { ::TestClass::Error.new }
    copy
  end

  def test_false_value_exception
    copy = guard @false { ::TestClass::Error.new }
    copy
  end

  def test_int_assign_exception
    guard(copy = @int) { ::TestClass::Error.new }
    copy
  end

  def test_nil_assign_exception
    guard(copy = @nil) { ::TestClass::Error.new }
    copy
  end

  def test_false_assign_exception
    guard(copy = @false) { ::TestClass::Error.new }
    copy
  end

  def test_int_value_with_false
    copy = guard! @int
    copy
  end

  def test_nil_value_with_false
    copy = guard! @nil
    copy
  end

  def test_false_value_with_false
    copy = guard! @false
    copy
  end

  def test_int_assign_with_false
    guard! copy = @int
    copy
  end

  def test_nil_assign_with_false
    guard! copy = @nil
    copy
  end

  def test_false_assign_with_false
    guard! copy = @false
    copy
  end

  def test_int_value_exception_with_false
    copy = guard! @int { ::TestClass::Error.new }
    copy
  end

  def test_nil_value_exception_with_false
    copy = guard! @nil { ::TestClass::Error.new }
    copy
  end

  def test_false_value_exception_with_false
    copy = guard! @false { ::TestClass::Error.new }
    copy
  end

  def test_int_assign_exception_with_false
    guard!(copy = @int) { ::TestClass::Error.new }
    copy
  end

  def test_nil_assign_exception_with_false
    guard!(copy = @nil) { ::TestClass::Error.new }
    copy
  end

  def test_false_assign_exception_with_false
    guard!(copy = @false) { ::TestClass::Error.new }
    copy
  end

  class Error < Exception; end
end
