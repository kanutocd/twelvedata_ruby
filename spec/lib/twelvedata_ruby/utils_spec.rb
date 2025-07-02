# frozen_string_literal: true

RSpec.describe TwelvedataRuby::Utils do
  describe ".demodulize" do
    it "removes module namespace from class name" do
      expect(described_class.demodulize(TwelvedataRuby::Error)).to eq("Error")
      expect(described_class.demodulize(TwelvedataRuby::Client)).to eq("Client")
      expect(described_class.demodulize("TwelvedataRuby::Response")).to eq("Response")
    end

    it "handles classes without namespaces" do
      expect(described_class.demodulize(String)).to eq("String")
      expect(described_class.demodulize("Array")).to eq("Array")
    end

    it "handles nested modules" do
      expect(described_class.demodulize("A::B::C::Class")).to eq("Class")
    end

    it "handles edge cases" do
      expect(described_class.demodulize("")).to eq("")
      expect(described_class.demodulize(nil)).to eq("")
    end
  end

  describe ".to_integer" do
    context "with valid integer strings" do
      it "converts string to integer" do
        expect(described_class.to_integer("123")).to eq(123)
        expect(described_class.to_integer("0")).to eq(0)
        expect(described_class.to_integer("999")).to eq(999)
      end
    end

    context "with integers" do
      it "returns the integer unchanged" do
        expect(described_class.to_integer(123)).to eq(123)
        expect(described_class.to_integer(0)).to eq(0)
        expect(described_class.to_integer(-5)).to eq(-5)
      end
    end

    context "with invalid inputs" do
      it "returns default value for non-numeric strings" do
        expect(described_class.to_integer("abc")).to be_nil
        expect(described_class.to_integer("12.34")).to be_nil
        expect(described_class.to_integer("12a")).to be_nil
      end

      it "returns custom default value" do
        expect(described_class.to_integer("abc", 0)).to eq(0)
        expect(described_class.to_integer("xyz", 42)).to eq(42)
      end
    end

    context "with edge cases" do
      it "handles nil input" do
        expect(described_class.to_integer(nil)).to be_nil
        expect(described_class.to_integer(nil, 100)).to eq(100)
      end

      it "handles empty string" do
        expect(described_class.to_integer("")).to be_nil
        expect(described_class.to_integer("", 50)).to eq(50)
      end

      it "handles large numbers" do
        expect(described_class.to_integer("999999999")).to eq(999_999_999)
      end
    end
  end

  describe ".camelize" do
    it "converts snake_case to CamelCase" do
      expect(described_class.camelize("snake_case")).to eq("SnakeCase")
      expect(described_class.camelize("api_key_name")).to eq("ApiKeyName")
      expect(described_class.camelize("single")).to eq("Single")
    end

    it "handles edge cases" do
      expect(described_class.camelize("")).to eq("")
      expect(described_class.camelize("_")).to eq("")
      expect(described_class.camelize("__double__")).to eq("Double")
    end

    it "handles symbols" do
      expect(described_class.camelize(:snake_case)).to eq("SnakeCase")
    end

    it "handles nil" do
      expect(described_class.camelize(nil)).to eq("")
    end
  end

  describe ".empty_to_nil" do
    context "with empty values" do
      it "converts empty string to nil" do
        expect(described_class.empty_to_nil("")).to be_nil
      end

      it "converts empty array to nil" do
        expect(described_class.empty_to_nil([])).to be_nil
      end

      it "converts empty hash to nil" do
        expect(described_class.empty_to_nil({})).to be_nil
      end
    end

    context "with nil values" do
      it "returns nil for nil input" do
        expect(described_class.empty_to_nil(nil)).to be_nil
      end
    end

    context "with non-empty values" do
      it "returns string unchanged" do
        expect(described_class.empty_to_nil("test")).to eq("test")
      end

      it "returns array unchanged" do
        expect(described_class.empty_to_nil([1, 2, 3])).to eq([1, 2, 3])
      end

      it "returns hash unchanged" do
        expect(described_class.empty_to_nil({ key: "value" })).to eq({ key: "value" })
      end

      it "returns numbers unchanged" do
        expect(described_class.empty_to_nil(0)).to eq(0)
        expect(described_class.empty_to_nil(123)).to eq(123)
      end
    end

    context "with objects without empty? method" do
      it "returns object unchanged" do
        object = Object.new
        expect(described_class.empty_to_nil(object)).to be(object)
      end
    end
  end

  describe ".to_array" do
    it "returns array unchanged" do
      array = [1, 2, 3]
      expect(described_class.to_array(array)).to eq([1, 2, 3])
      expect(described_class.to_array(array)).to be(array)
    end

    it "wraps non-array in array" do
      expect(described_class.to_array("test")).to eq(["test"])
      expect(described_class.to_array(123)).to eq([123])
      expect(described_class.to_array(nil)).to eq([nil])
    end

    it "handles empty array" do
      expect(described_class.to_array([])).to eq([])
    end
  end

  describe ".execute_if_truthy" do
    context "with truthy conditions" do
      it "executes block and returns result" do
        result = described_class.execute_if_truthy(true) { "executed" }
        expect(result).to eq("executed")
      end

      it "works with truthy values" do
        result = described_class.execute_if_truthy("string") { "executed" }
        expect(result).to eq("executed")

        result = described_class.execute_if_truthy(1) { "executed" }
        expect(result).to eq("executed")
      end
    end

    context "with falsy conditions" do
      it "returns default value without executing block" do
        executed = false
        result = described_class.execute_if_truthy(false, "default") do
          executed = true
          "should not execute"
        end

        expect(result).to eq("default")
        expect(executed).to be(false)
      end

      it "works with nil condition" do
        result = described_class.execute_if_truthy(nil, "default") { "executed" }
        expect(result).to eq("default")
      end
    end

    context "without block" do
      it "returns default value" do
        result = described_class.execute_if_truthy(true, "default")
        expect(result).to eq("default")
      end
    end
  end

  describe ".execute_if_true" do
    it "executes block only when condition is exactly true" do
      result = described_class.execute_if_true(true) { "executed" }
      expect(result).to eq("executed")
    end

    it "does not execute for truthy but not true values" do
      executed = false

      described_class.execute_if_true("string") { executed = true }
      expect(executed).to be(false)

      described_class.execute_if_true(1) { executed = true }
      expect(executed).to be(false)
    end

    it "does not execute for false" do
      executed = false
      described_class.execute_if_true(false) { executed = true }
      expect(executed).to be(false)
    end

    it "returns nil when condition is not true" do
      result = described_class.execute_if_true("truthy") { "executed" }
      expect(result).to be_nil
    end
  end

  describe ".present?" do
    context "with present values" do
      it "returns true for non-empty strings" do
        expect(described_class.present?("test")).to be(true)
        expect(described_class.present?("  text  ")).to be(true)
      end

      it "returns true for non-empty collections" do
        expect(described_class.present?([1, 2, 3])).to be(true)
        expect(described_class.present?({ key: "value" })).to be(true)
      end

      it "returns true for numbers" do
        expect(described_class.present?(0)).to be(true)
        expect(described_class.present?(123)).to be(true)
      end

      it "returns true for objects" do
        expect(described_class.present?(Object.new)).to be(true)
      end
    end

    context "with blank values" do
      it "returns false for nil" do
        expect(described_class.present?(nil)).to be(false)
      end

      it "returns false for empty string" do
        expect(described_class.present?("")).to be(false)
      end

      it "returns false for whitespace-only string" do
        expect(described_class.present?("   ")).to be(false)
        expect(described_class.present?("\t\n")).to be(false)
      end

      it "returns false for empty collections" do
        expect(described_class.present?([])).to be(false)
        expect(described_class.present?({})).to be(false)
      end
    end
  end

  describe ".blank?" do
    it "is the opposite of present?" do
      test_values = [
        nil, "", "   ", "\t\n", [], {},
        "test", [1], { a: 1 }, 0, 123, Object.new
      ]

      test_values.each do |value|
        expect(described_class.blank?(value)).to eq(!described_class.present?(value))
      end
    end
  end

  describe "module consistency" do
    let(:expected_methods) { %w[demodulize to_integer camelize empty_to_nil
                                execute_if_truthy execute_if_true present? blank?] }
    it "has all expected public methods" do
      actual_methods = described_class.methods(false).map(&:to_s)
      expect(actual_methods).to include(*expected_methods)
    end

    it "does not expose private methods" do
      # All methods should be public class methods
      expect(described_class.private_methods & expected_methods).to be_empty
    end
  end
end
