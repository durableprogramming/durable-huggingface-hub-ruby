# frozen_string_literal: true

require_relative "validators"

module DurableHuggingfaceHub
  module Utils
    # HTTP header building utilities for HuggingFace Hub API requests.
    #
    # This module provides functions for constructing proper HTTP headers
    # including User-Agent, Authorization, and custom headers.
    module Headers
      # Builds standard headers for HuggingFace Hub API requests.
      #
      # @param token [String, nil] Authentication token
      # @param library_name [String, nil] Name of the library using this client
      # @param library_version [String, nil] Version of the library
      # @param user_agent [String, nil] Custom user agent string
      # @param headers [Hash, nil] Additional custom headers
      # @return [Hash] Complete headers hash
      # @raise [ValidationError] If any parameter has invalid type or format
      #
      # @example Basic usage
      #   headers = Headers.build_hf_headers(token: "hf_...")
      #
      # @example With custom library info
      #   headers = Headers.build_hf_headers(
      #     token: "hf_...",
      #     library_name: "my_app",
      #     library_version: "1.0.0"
      #   )
      def self.build_hf_headers(token: nil, library_name: nil, library_version: nil, user_agent: nil, headers: nil)
        # Validate parameters
        if token && !token.is_a?(String)
          raise ValidationError.new("token", "Token must be a string")
        end

        if library_name && !library_name.is_a?(String)
          raise ValidationError.new("library_name", "Library name must be a string")
        end

        if library_version && !library_version.is_a?(String)
          raise ValidationError.new("library_version", "Library version must be a string")
        end

        if user_agent && !user_agent.is_a?(String)
          raise ValidationError.new("user_agent", "User agent must be a string")
        end

        if headers && !headers.is_a?(Hash)
          raise ValidationError.new("headers", "Custom headers must be a hash")
        end

        result = {}

        # User-Agent header
        result["User-Agent"] = build_user_agent(
          library_name: library_name,
          library_version: library_version,
          custom_agent: user_agent
        )

        # Authorization header
        if token
          result["Authorization"] = "Bearer #{token}"
        end

        # Merge custom headers
        if headers
          result.merge!(headers)
        end

        result
      end

      # Builds a User-Agent string for HTTP requests.
      #
      # Format: "[custom] [library/version] huggingface_hub/version; ruby/version"
      #
      # @param library_name [String, nil] Name of the calling library
      # @param library_version [String, nil] Version of the calling library
      # @param custom_agent [String, nil] Custom user agent to prepend
      # @return [String] User-Agent string
      # @raise [ValidationError] If any parameter has invalid type
      #
      # @example
      #   Headers.build_user_agent
      #   # => "huggingface_hub/0.1.0; ruby/3.3.0"
      #
      # @example With library info
      #   Headers.build_user_agent(library_name: "transformers", library_version: "4.0.0")
      #   # => "transformers/4.0.0 huggingface_hub/0.1.0; ruby/3.3.0"
      def self.build_user_agent(library_name: nil, library_version: nil, custom_agent: nil)
        # Validate parameters
        if library_name && !library_name.is_a?(String)
          raise ValidationError.new("library_name", "Library name must be a string")
        end

        if library_version && !library_version.is_a?(String)
          raise ValidationError.new("library_version", "Library version must be a string")
        end

        if custom_agent && !custom_agent.is_a?(String)
          raise ValidationError.new("custom_agent", "Custom agent must be a string")
        end

        parts = []

        # Custom agent
        parts << custom_agent if custom_agent

        # Library identification
        if library_name && library_version && !library_version.empty?
          parts << "#{library_name}/#{library_version}"
        elsif library_name && !library_name.empty?
          parts << library_name
        end

        # HuggingFace Hub client identification
        hf_part = "huggingface_hub/#{DurableHuggingfaceHub::VERSION}"

        # Ruby version
        ruby_part = "ruby/#{RUBY_VERSION}"

        # Join library/custom parts with space, then add hf; ruby
        library_part = parts.empty? ? "" : "#{parts.join(" ")} "
        "#{library_part}#{hf_part}; #{ruby_part}"
      end

      # Extracts request ID from response headers.
      #
      # @param headers [Hash] Response headers
      # @return [String, nil] Request ID if present
      # @raise [ValidationError] If headers is not a hash
      def self.extract_request_id(headers)
        if headers && !headers.is_a?(Hash)
          raise ValidationError.new("headers", "Headers must be a hash")
        end

        return nil unless headers

        # Try common header names
        headers["X-Request-Id"] ||
          headers["x-request-id"] ||
          headers["Request-Id"] ||
          headers["request-id"]
      end

      # Extracts commit SHA from response headers.
      #
      # @param headers [Hash] Response headers
      # @return [String, nil] Commit SHA if present
      # @raise [ValidationError] If headers is not a hash
      def self.extract_commit_sha(headers)
        if headers && !headers.is_a?(Hash)
          raise ValidationError.new("headers", "Headers must be a hash")
        end

        return nil unless headers

        headers[Constants::HEADER_X_REPO_COMMIT] ||
          headers[Constants::HEADER_X_REPO_COMMIT.downcase]
      end

      # Extracts ETag from response headers.
      #
      # @param headers [Hash] Response headers
      # @return [String, nil] ETag value (with quotes removed)
      # @raise [ValidationError] If headers is not a hash
      def self.extract_etag(headers)
        if headers && !headers.is_a?(Hash)
          raise ValidationError.new("headers", "Headers must be a hash")
        end

        return nil unless headers

        etag = headers["ETag"] || headers["etag"]
        return nil unless etag

        # Remove surrounding quotes if present
        etag.gsub(/^"|"$/, "")
      end

      # Extracts linked file size from response headers.
      #
      # @param headers [Hash] Response headers
      # @return [Integer, nil] File size in bytes
      # @raise [ValidationError] If headers is not a hash
      def self.extract_linked_size(headers)
        if headers && !headers.is_a?(Hash)
          raise ValidationError.new("headers", "Headers must be a hash")
        end

        return nil unless headers

        size = headers[Constants::HEADER_X_LINKED_SIZE] ||
               headers[Constants::HEADER_X_LINKED_SIZE.downcase]

        size&.to_i
      end

      # Checks if response indicates the file is stored in LFS.
      #
      # @param headers [Hash] Response headers
      # @return [Boolean] True if file is in LFS
      # @raise [ValidationError] If headers is not a hash
      def self.lfs_file?(headers)
        if headers && !headers.is_a?(Hash)
          raise ValidationError.new("headers", "Headers must be a hash")
        end

        return false unless headers

        etag = headers[Constants::HEADER_X_LINKED_ETAG] ||
               headers[Constants::HEADER_X_LINKED_ETAG.downcase]

        !etag.nil?
      end
    end
  end
end
