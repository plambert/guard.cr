require "./spec_helper"

describe Guard do
  it "returns nil or the value" do
    thing = TestClass.new
    thing.test_int_value.should eq 7
    thing.test_nil_value.should be_nil
    thing.test_false_value.should be_nil
  end

  it "returns nil or performs assignment" do
    thing = TestClass.new
    thing.test_int_assign.should eq 7
    thing.test_nil_assign.should be_nil
    thing.test_false_assign.should be_nil
  end

  it "returns the value or raises an exception" do
    thing = TestClass.new
    thing.test_int_value_exception.should eq 7
    expect_raises TestClass::Error do
      thing.test_nil_value_exception.should be_nil
    end
    expect_raises TestClass::Error do
      thing.test_false_value_exception.should be_nil
    end
  end

  it "performs assignment or raises" do
    thing = TestClass.new
    thing.test_int_assign_exception.should eq 7
    expect_raises TestClass::Error do
      thing.test_nil_assign_exception.should be_nil
    end
    expect_raises TestClass::Error do
      thing.test_false_assign_exception.should be_nil
    end
  end

  it "allows false as a value" do
    thing = TestClass.new
    thing.test_int_value_with_false.should eq 7
    thing.test_nil_value_with_false.should be_nil
    thing.test_false_value_with_false.should be_false
    thing.test_int_assign_with_false.should eq 7
    thing.test_nil_assign_with_false.should be_nil
    thing.test_false_assign_with_false.should be_false
    thing.test_int_value_exception_with_false.should eq 7
    expect_raises TestClass::Error do
      thing.test_nil_value_exception_with_false.should be_nil
    end
    thing.test_false_value_exception_with_false.should be_false
    thing.test_int_assign_exception_with_false.should eq 7
    expect_raises TestClass::Error do
      thing.test_nil_assign_exception_with_false.should be_nil
    end
    thing.test_false_assign_exception_with_false.should be_false
  end
end
