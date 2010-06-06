require File.expand_path('../../test_helper', __FILE__)

class EnvironmentTest < ActiveSupport::TestCase
  context "The text environment" do
    should "load fixtures" do
      assert_equal Person.count, 1, "Should have loaded 1 fixture"
    end

    should "save to sqlite" do
      assert_equal Person.count, 1, "Should have loaded 1 fixture"
      p = Person.create :name => "Bob"
      assert_equal Person.count, 2, "Should be 2 people now"
      assert_equal p.name, "Bob", "Name should be Bob" 
    end

    should "relaod fixtures each time" do
      assert_equal Person.count, 1, "Should have loaded 1 fixture"
      p = Person.create :name => "Bob"
      assert_equal Person.count, 2, "Should be 2 people now"
      assert_equal p.name, "Bob", "Name should be Bob" 
    end
  end
end
