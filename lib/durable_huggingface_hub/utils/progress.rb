# frozen_string_literal: true

module DurableHuggingfaceHub
  module Utils
    # Progress tracking for long-running operations.
    #
    # This module provides a simple progress tracking mechanism for operations
    # like file downloads. It supports custom callbacks for progress updates.
    #
    # @example Basic progress tracking
    #   progress = Progress.new(total: 1000)
    #   progress.update(100)  # 10% complete
    #   progress.update(500)  # 50% complete
    #   progress.finish
    #
    # @example With callback
    #   progress = Progress.new(total: 1000) do |current, total, percentage|
    #     puts "Progress: #{percentage.round(1)}% (#{current}/#{total})"
    #   end
    #   progress.update(500)  # Calls callback
    class Progress
      # @return [Integer, nil] Total size/count expected
      attr_reader :total

      # @return [Integer] Current progress
      attr_reader :current

       # @return [Time] Start time
       attr_reader :start_time

       # Creates a new Progress tracker.
       #
       # @param total [Integer, nil] Total size/count expected
       # @param callback [Proc, nil] Callback to invoke on updates
       # @yield [current, total, percentage] Optional block called on updates
       # @yieldparam current [Integer] Current progress
       # @yieldparam total [Integer, nil] Total expected
       # @yieldparam percentage [Float] Percentage complete (0-100)
       # @raise [ValidationError] If total is provided but not positive
       def initialize(total: nil, callback: nil, &block)
         validate_total(total)
         @total = total
         @current = 0
         @start_time = Time.now
         @callback = callback || block
         @finished = false
       end

       # Updates the progress.
       #
       # @param amount [Integer] Amount to add to current progress
       # @return [void]
       # @raise [ValidationError] If amount is negative
       def update(amount)
         return if @finished

         validate_amount(amount)
         @current += amount
         notify_callback
       end

       # Sets the current progress to a specific value.
       #
       # @param value [Integer] New current value
       # @return [void]
       # @raise [ValidationError] If value is negative
       def set(value)
         return if @finished

         validate_value(value)
         @current = value
         notify_callback
       end

      # Marks the progress as finished.
      #
      # @return [void]
      def finish
        return if @finished

        @finished = true
        @current = @total if @total
        notify_callback
      end

      # Checks if progress is finished.
      #
      # @return [Boolean] True if finished
      def finished?
        @finished
      end

      # Calculates the percentage complete.
      #
      # @return [Float, nil] Percentage (0-100) or nil if total unknown
      def percentage
        return nil unless @total&.positive?

        (@current.to_f / @total * 100).round(2)
      end

      # Calculates elapsed time.
      #
      # @return [Float] Elapsed seconds
      def elapsed
        Time.now - @start_time
      end

       # Estimates time remaining.
       #
       # @return [Float, nil] Estimated seconds remaining or nil if unknown
       def eta
         return nil unless @total&.positive? && @current.positive?

         elapsed_time = elapsed
         return nil if elapsed_time <= 0

         rate = @current.to_f / elapsed_time
         remaining = @total - @current
         remaining / rate
       end

       # Resets the progress tracker to its initial state.
       #
       # @return [void]
       def reset
         @current = 0
         @start_time = Time.now
         @finished = false
         notify_callback
       end

       # Returns a string representation of the progress.
       #
       # @return [String] String representation
       def to_s
         if @total
           "#{@current}/#{@total} (#{percentage&.round(1)}%)"
         else
           "#{@current} completed"
         end
       end

       private

       # Validates the total parameter.
       #
       # @param total [Integer, nil] Total value to validate
       # @raise [ValidationError] If total is provided but not positive
       def validate_total(total)
         return if total.nil?

         unless total.is_a?(Integer) && total.positive?
           raise ValidationError.new("total", "Total must be a positive integer, got #{total.inspect}")
         end
       end

       # Validates the amount parameter.
       #
       # @param amount [Integer] Amount to validate
       # @raise [ValidationError] If amount is negative
       def validate_amount(amount)
         unless amount.is_a?(Integer) && amount >= 0
           raise ValidationError.new("amount", "Amount must be a non-negative integer, got #{amount.inspect}")
         end
       end

       # Validates the value parameter.
       #
       # @param value [Integer] Value to validate
       # @raise [ValidationError] If value is negative
       def validate_value(value)
         unless value.is_a?(Integer) && value >= 0
           raise ValidationError.new("value", "Value must be a non-negative integer, got #{value.inspect}")
         end
       end

       # Notifies the callback of progress update.
       def notify_callback
         return unless @callback

         @callback.call(@current, @total, percentage)
       end
     end

     # No-op progress tracker for when progress tracking is disabled.
     class NullProgress
       def update(_amount); end

       def set(_value); end

       def finish; end

       def finished?
         false
       end

       def percentage
         nil
       end

       def elapsed
         0
       end

       def eta
         nil
       end

       def reset; end

       def to_s
         "NullProgress"
       end
     end
  end
end
