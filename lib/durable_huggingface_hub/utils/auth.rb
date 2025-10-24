# frozen_string_literal: true

require "pathname"
require "fileutils"

module DurableHuggingfaceHub
  module Utils
    # Authentication token management utilities.
    #
    # This module provides functions for retrieving, storing, and managing
    # HuggingFace authentication tokens.
    module Auth
      # File permissions for token storage (owner read/write only)
      TOKEN_FILE_PERMISSIONS = 0o600

      # Retrieves the authentication token from multiple sources.
      #
      # Priority order:
      # 1. Explicitly provided token parameter
      # 2. HF_TOKEN environment variable
      # 3. HUGGING_FACE_HUB_TOKEN environment variable
      # 4. Token file (~/.cache/huggingface/token)
      #
      # @param token [String, nil] Explicitly provided token
      # @return [String, nil] Authentication token or nil if not found
      #
      # @example Explicit token
      #   Auth.get_token(token: "hf_...")
      #
      # @example From environment or file
      #   Auth.get_token  # Checks ENV then file
      def self.get_token(token: nil)
        # Priority 1: Explicit parameter
        return token if token && !token.empty?

        # Priority 2: HF_TOKEN environment variable
        env_token = ENV["HF_TOKEN"]
        return env_token if env_token && !env_token.empty?

        # Priority 3: HUGGING_FACE_HUB_TOKEN environment variable
        legacy_token = ENV["HUGGING_FACE_HUB_TOKEN"]
        return legacy_token if legacy_token && !legacy_token.empty?

        # Priority 4: Token file
        read_token_from_file
      end

      # Reads the authentication token from the token file.
      #
      # @return [String, nil] Token from file or nil if not found
      def self.read_token_from_file
        token_path = get_token_path
        return nil unless File.exist?(token_path)

        token = File.read(token_path).strip
        token.empty? ? nil : token
      rescue Errno::EACCES, Errno::ENOENT
        nil
      end

      # Writes the authentication token to the token file.
      #
      # Creates the cache directory if it doesn't exist and sets
      # appropriate file permissions for security.
      #
      # @param token [String] Token to store
      # @return [Boolean] True if successful
      # @raise [IOError] If unable to write token
      #
      # @example
      #   Auth.write_token_to_file("hf_...")
      def self.write_token_to_file(token)
        token_path = get_token_path

        # Ensure cache directory exists
        token_path.dirname.mkpath unless token_path.dirname.exist?

        # Write token atomically
        temp_path = Pathname.new("#{token_path}.tmp")
        temp_path.write(token)

        # Set restrictive permissions before moving
        File.chmod(TOKEN_FILE_PERMISSIONS, temp_path)

        # Atomic move
        File.rename(temp_path, token_path)

        true
      rescue => e
        # Clean up temp file if it exists
        temp_path&.delete if temp_path&.exist?
        raise IOError, "Failed to write token: #{e.message}"
      end

      # Deletes the token file.
      #
      # @return [Boolean] True if file was deleted, false if it didn't exist
      def self.delete_token_file
        token_path = get_token_path
        return false unless token_path.exist?

        token_path.delete
        true
      rescue Errno::EACCES, Errno::ENOENT
        false
      end

      # Returns the path to the token file.
      #
      # @return [Pathname] Path to token file
      def self.get_token_path
        Configuration.instance.token_path
      end

      # Validates a token format.
      #
      # HuggingFace tokens typically start with "hf_" and are alphanumeric.
      #
      # @param token [String] Token to validate
      # @return [Boolean] True if token format appears valid
      #
      # @example
      #   Auth.valid_token_format?("hf_abc123")  # => true
      #   Auth.valid_token_format?("invalid")     # => false
      def self.valid_token_format?(token)
        return false if token.nil? || token.empty?

        # HuggingFace tokens start with "hf_" followed by alphanumeric characters
        # Minimum reasonable length is around 10 characters
        token.match?(/\Ahf_[A-Za-z0-9_-]{8,}\z/)
      end

      # Retrieves a token and raises an error if not found.
      #
      # @param token [String, nil] Explicitly provided token
      # @return [String] Authentication token
      # @raise [LocalTokenNotFoundError] If no token is available
      #
      # @example
      #   token = Auth.get_token!  # Raises if not found
      def self.get_token!(token: nil)
        result = get_token(token: token)
        return result if result

        raise LocalTokenNotFoundError.new
      end

      # Masks a token for safe display.
      #
      # Shows first 7 characters and last 4 characters, masking the middle.
      #
      # @param token [String] Token to mask
      # @return [String] Masked token
      #
      # @example
      #   Auth.mask_token("hf_abc123def456ghi789")
      #   # => "hf_abc1...h789"
      def self.mask_token(token)
        return "" if token.nil? || token.empty?
        return token if token.length <= 11

        if token.length <= 15
          prefix = token[0, 4]
          suffix = token[-1]
          "#{prefix}...#{suffix}"
        else
          prefix = token[0, 7]
          suffix = token[-4..]
          "#{prefix}...#{suffix}"
        end
      end
    end
  end
end
