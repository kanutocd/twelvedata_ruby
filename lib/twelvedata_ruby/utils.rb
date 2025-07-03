# frozen_string_literal: true

# Utility methods for common operations
module TwelvedataRuby::Utils
  class << self
    # Removes module namespace from class name
    #
    # @param obj [Object] Object to extract class name from
    # @return [String] Class name without module namespace
    #
    # @example
    #   Utils.demodulize(TwelvedataRuby::Error) #=> "Error"
    def demodulize(obj)
      obj.to_s.gsub(/^.+::/, "")
    end

    # Converts string to integer with default fallback
    #
    # @param obj [Object] Object to convert
    # @param default_value [Integer, nil] Default value if conversion fails
    # @return [Integer, nil] Converted integer or default value
    #
    # @example
    #   Utils.to_integer("123") #=> 123
    #   Utils.to_integer("abc", 0) #=> 0
    def to_integer(obj, default_value = nil)
      obj.is_a?(Integer) ? obj : Integer(obj.to_s)
    rescue ArgumentError
      default_value
    end

    # Converts snake_case to CamelCase
    #
    # @param str [String] String to convert
    # @return [String] CamelCase string
    #
    # @example
    #   Utils.camelize("snake_case") #=> "SnakeCase"
    def camelize(str)
      str.to_s.split("_").map(&:capitalize).join
    end

    # Converts empty values to nil
    #
    # @param obj [Object] Object to check
    # @return [Object, nil] Original object or nil if empty
    #
    # @example
    #   Utils.empty_to_nil("") #=> nil
    #   Utils.empty_to_nil("test") #=> "test"
    def empty_to_nil(obj)
      return nil if obj.nil?
      return nil if obj.respond_to?(:empty?) && obj.empty?

      obj
    end

    # Ensures return value is an array
    #
    # @param objects [Object] Single object or array
    # @return [Array] Array containing the objects
    #
    # @example
    #   Utils.to_array("test") #=> ["test"]
    #   Utils.to_array(["a", "b"]) #=> ["a", "b"]
    def to_array(objects)
      objects.is_a?(Array) ? objects : [objects]
    end

    # Executes block if condition is truthy
    #
    # @param condition [Object] Condition to evaluate
    # @param default_return [Object] Default return value
    # @yield Block to execute if condition is truthy
    # @return [Object] Block result or default value
    def execute_if_truthy(condition, default_return = nil)
      return default_return unless condition && block_given?

      yield
    end

    # Executes block only if condition is exactly true
    #
    # @param condition [Object] Condition to evaluate
    # @yield Block to execute if condition is true
    # @return [Object, nil] Block result or nil
    def execute_if_true(condition, &block)
      execute_if_truthy(condition == true, &block)
    end

    # Validates that a value is not blank
    #
    # @param value [Object] Value to validate
    # @return [Boolean] True if value is present
    def present?(value)
      !blank?(value)
    end

    # Checks if a value is blank (nil, empty, or whitespace-only)
    #
    # @param value [Object] Value to check
    # @return [Boolean] True if value is blank
    def blank?(value)
      return true if value.nil?
      return true if value.respond_to?(:empty?) && value.empty?
      return true if value.is_a?(String) && value.strip.empty?

      false
    end
  end
end
