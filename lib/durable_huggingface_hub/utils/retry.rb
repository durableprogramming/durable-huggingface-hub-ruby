# frozen_string_literal: true

require "faraday"

module DurableHuggingfaceHub
  module Utils
    # Retry logic with exponential backoff for HTTP requests.
    #
    # This module provides retry functionality for handling transient failures
    # in HTTP requests, with configurable retry attempts and exponential backoff.
    module Retry
      # Default maximum number of retry attempts
      DEFAULT_MAX_RETRIES = 3

      # Default initial delay in seconds
      DEFAULT_INITIAL_DELAY = 1

      # Maximum delay between retries (in seconds)
      MAX_DELAY = 60

      # Multiplier for exponential backoff
      BACKOFF_MULTIPLIER = 2

      # HTTP status codes that should trigger a retry
      RETRYABLE_STATUS_CODES = [
        408, # Request Timeout
        429, # Too Many Requests
        500, # Internal Server Error
        502, # Bad Gateway
        503, # Service Unavailable
        504  # Gateway Timeout
      ].freeze

      # Errors that should trigger a retry
      RETRYABLE_ERRORS = [
        Faraday::TimeoutError,
        Faraday::ConnectionFailed,
        Faraday::SSLError
      ].freeze

      # Executes a block with retry logic.
      #
      # @param max_retries [Integer] Maximum number of retry attempts (must be >= 0)
      # @param initial_delay [Float] Initial delay in seconds (must be > 0)
      # @param logger [Logger, nil] Logger for retry messages
      # @yield Block to execute with retry
      # @yieldreturn Result of the block
      # @return Result of the block if successful
      # @raise [ArgumentError] If parameters are invalid
      # @raise Last exception if all retries exhausted
      #
      # @example Basic usage
      #   result = Retry.with_retry do
      #     perform_http_request
      #   end
      #
      # @example Custom retry configuration
      #   result = Retry.with_retry(max_retries: 5, initial_delay: 2) do
      #     risky_operation
      #   end
      def self.with_retry(max_retries: DEFAULT_MAX_RETRIES, initial_delay: DEFAULT_INITIAL_DELAY, logger: nil)
        # Validate parameters
        validate_max_retries(max_retries)
        validate_initial_delay(initial_delay)

        attempt = 0
        last_error = nil

        loop do
          begin
            return yield
          rescue => e
            attempt += 1
            last_error = e

            # Check if error is retryable
            unless retryable_error?(e)
              raise e
            end

            # Check if we've exhausted retries
            if attempt > max_retries
              logger&.error("Max retries (#{max_retries}) exhausted for #{e.class}: #{e.message}")
              raise e
            end

            # Calculate delay with exponential backoff
            delay = calculate_delay(attempt, initial_delay)

            # Log retry attempt
            logger&.warn("Retry attempt #{attempt}/#{max_retries} after #{delay}s due to #{e.class}: #{e.message}")

            # Wait before retrying
            sleep(delay)
          end
        end
      end

      # Checks if an error should trigger a retry.
      #
      # @param error [Exception] The error to check
      # @return [Boolean] True if error is retryable
      def self.retryable_error?(error)
        # Check if it's a known retryable error class
        return true if RETRYABLE_ERRORS.any? { |klass| error.is_a?(klass) }

        # Check if it's an HTTP error with retryable status
        if error.is_a?(HfHubHTTPError) && error.status_code
          return RETRYABLE_STATUS_CODES.include?(error.status_code)
        end

        # Check Faraday response errors
        if error.respond_to?(:response) && error.response
          status = error.response[:status]
          return RETRYABLE_STATUS_CODES.include?(status) if status
        end

        false
      end

      # Calculates the delay for a retry attempt using exponential backoff.
      #
      # @param attempt [Integer] Current attempt number (1-based)
      # @param initial_delay [Float] Initial delay in seconds
      # @return [Float] Delay in seconds (capped at MAX_DELAY)
      #
      # @example
      #   Retry.calculate_delay(1, 1.0)  # => 1.0
      #   Retry.calculate_delay(2, 1.0)  # => 2.0
      #   Retry.calculate_delay(3, 1.0)  # => 4.0
      #   Retry.calculate_delay(4, 1.0)  # => 8.0
       def self.calculate_delay(attempt, initial_delay)
         # Exponential backoff: initial_delay * (2 ^ (attempt - 1))
         delay = initial_delay * (BACKOFF_MULTIPLIER**(attempt - 1))

         # Cap at maximum delay
         [delay, MAX_DELAY].min
       end

       # Validates the max_retries parameter.
       #
       # @param max_retries [Integer] Maximum number of retry attempts
       # @raise [ArgumentError] If max_retries is invalid
       # @private
       def self.validate_max_retries(max_retries)
         unless max_retries.is_a?(Integer) && max_retries >= 0
           raise ArgumentError, "max_retries must be a non-negative integer, got #{max_retries.inspect}"
         end
       end
       private_class_method :validate_max_retries

       # Validates the initial_delay parameter.
       #
       # @param initial_delay [Numeric] Initial delay in seconds
       # @raise [ArgumentError] If initial_delay is invalid
       # @private
       def self.validate_initial_delay(initial_delay)
         unless initial_delay.is_a?(Numeric) && initial_delay > 0
           raise ArgumentError, "initial_delay must be a positive number, got #{initial_delay.inspect}"
         end
       end
       private_class_method :validate_initial_delay
     end
   end
 end
