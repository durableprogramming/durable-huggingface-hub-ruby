# frozen_string_literal: true

require "json"

module DurableHuggingfaceHub
  # Base error class for all HuggingFace Hub errors.
  #
  # All exceptions raised by this library inherit from this class,
  # allowing users to rescue all library-specific errors with a single rescue clause.
  #
  # @example Catching all library errors
  #   begin
  #     # HuggingFace Hub operations
  #   rescue DurableHuggingfaceHub::DurableHuggingfaceHubError => e
  #     puts "HuggingFace Hub error: #{e.message}"
  #   end
  class DurableHuggingfaceHubError < StandardError
  end

  # Base class for HTTP-related errors from the HuggingFace Hub API.
  #
  # This error captures HTTP response details including status code,
  # response body, request ID, and parsed server messages.
  #
  # @example Accessing error details
  #   begin
  #     # API call
  #   rescue DurableHuggingfaceHub::HfHubHTTPError => e
  #     puts "Status: #{e.status_code}"
  #     puts "Message: #{e.server_message}"
  #     puts "Request ID: #{e.request_id}"
  #   end
  class HfHubHTTPError < DurableHuggingfaceHubError
    # @return [Integer] HTTP status code
    attr_reader :status_code

    # @return [String, nil] Response body from the server
    attr_reader :response_body

    # @return [String, nil] Request ID for tracking purposes
    attr_reader :request_id

    # @return [String, nil] Parsed server error message
    attr_reader :server_message

    # Creates a new HTTP error.
    #
    # @param message [String] Error message
    # @param status_code [Integer] HTTP status code
    # @param response_body [String, nil] Response body from server
    # @param request_id [String, nil] Request ID for tracking
    def initialize(message, status_code: nil, response_body: nil, request_id: nil)
      super(message)
      @status_code = status_code
      @response_body = response_body
      @request_id = request_id
      @server_message = parse_server_message(response_body)
    end

    private

    # Parses the server error message from response body.
    #
    # Attempts to extract error message from JSON response body.
    # Falls back to raw response if JSON parsing fails.
    #
    # @param body [String, nil] Response body
    # @return [String, nil] Parsed error message
    def parse_server_message(body)
      return nil if body.nil? || body.empty?

      parsed = JSON.parse(body)
      parsed["error"] || parsed["message"]
    rescue JSON::ParserError
      # If JSON parsing fails, return truncated body
      body.length > 200 ? "#{body[0...200]}..." : body
    end
  end

  # MARK: - Repository Errors

  # Error raised when a repository is not found on HuggingFace Hub.
  #
  # This error occurs when attempting to access a repository that doesn't exist
  # or when the user doesn't have permission to access it.
  #
  # @example
  #   # Raised when repository doesn't exist
  #   raise RepositoryNotFoundError.new("organization/nonexistent-model")
  class RepositoryNotFoundError < HfHubHTTPError
    # @return [String] The repository ID that was not found
    attr_reader :repo_id

    # Creates a new repository not found error.
    #
    # @param repo_id [String] Repository ID
    # @param message [String, nil] Custom error message
    def initialize(repo_id, message: nil)
      @repo_id = repo_id
      message ||= "Repository not found: #{repo_id}"
      super(message, status_code: 404)
    end
  end

  # Error raised when a specific revision is not found in a repository.
  #
  # @example
  #   raise RevisionNotFoundError.new("main", repo_id: "bert-base")
  class RevisionNotFoundError < HfHubHTTPError
    # @return [String] The revision that was not found
    attr_reader :revision

    # @return [String] The repository ID
    attr_reader :repo_id

    # Creates a new revision not found error.
    #
    # @param revision [String] Revision (branch, tag, or commit)
    # @param repo_id [String, nil] Repository ID
    # @param message [String, nil] Custom error message
    def initialize(revision, repo_id: nil, message: nil)
      @revision = revision
      @repo_id = repo_id
      message ||= build_message
      super(message, status_code: 404)
    end

    private

    def build_message
      if repo_id
        "Revision '#{revision}' not found in repository '#{repo_id}'"
      else
        "Revision not found: #{revision}"
      end
    end
  end

  # Error raised when a specific file or entry is not found in a repository.
  #
  # @example
  #   raise EntryNotFoundError.new("config.json", repo_id: "bert-base")
  class EntryNotFoundError < HfHubHTTPError
    # @return [String] The file path that was not found
    attr_reader :path

    # @return [String, nil] The repository ID
    attr_reader :repo_id

    # Creates a new entry not found error.
    #
    # @param path [String] File path in repository
    # @param repo_id [String, nil] Repository ID
    # @param revision [String, nil] Revision
    # @param message [String, nil] Custom error message
    def initialize(path, repo_id: nil, revision: nil, message: nil)
      @path = path
      @repo_id = repo_id
      @revision = revision
      message ||= build_message
      super(message, status_code: 404)
    end

    private

    def build_message
      parts = ["Entry not found: #{path}"]
      parts << "in repository '#{repo_id}'" if repo_id
      parts << "at revision '#{@revision}'" if @revision
      parts.join(" ")
    end
  end

  # Error raised when a file is not found in the local cache.
  #
  # This error occurs when local_files_only mode is enabled and the requested
  # file is not available in the local cache.
  #
  # @example
  #   raise LocalEntryNotFoundError.new("File not found in cache")
  class LocalEntryNotFoundError < DurableHuggingfaceHubError
    # Creates a new local entry not found error.
    #
    # @param message [String] Error message
    def initialize(message)
      super(message)
    end
  end

  # Error raised when attempting to access a gated repository without proper access.
  #
  # Gated repositories require users to accept terms or have special permissions.
  #
  # @example
  #   raise GatedRepoError.new("meta-llama/Llama-2-7b")
  class GatedRepoError < HfHubHTTPError
    # @return [String] The gated repository ID
    attr_reader :repo_id

    # Creates a new gated repository error.
    #
    # @param repo_id [String] Repository ID
    # @param message [String, nil] Custom error message
    def initialize(repo_id, message: nil)
      @repo_id = repo_id
      message ||= "Repository '#{repo_id}' is gated. You must be authenticated and have access."
      super(message, status_code: 403)
    end
  end

  # Error raised when attempting to access a disabled repository.
  #
  # Repositories may be disabled due to policy violations or other reasons.
  #
  # @example
  #   raise DisabledRepoError.new("disabled/repo")
  class DisabledRepoError < HfHubHTTPError
    # @return [String] The disabled repository ID
    attr_reader :repo_id

    # Creates a new disabled repository error.
    #
    # @param repo_id [String] Repository ID
    # @param message [String, nil] Custom error message
    def initialize(repo_id, message: nil)
      @repo_id = repo_id
      message ||= "Repository '#{repo_id}' has been disabled."
      super(message, status_code: 403)
    end
  end

  # MARK: - Authentication Errors

  # Error raised when a request fails due to bad request parameters.
  #
  # @example
  #   raise BadRequestError.new("Invalid repository ID format")
  class BadRequestError < HfHubHTTPError
    # Creates a new bad request error.
    #
    # @param message [String] Error message
    # @param response_body [String, nil] Response body
    def initialize(message, response_body: nil)
      super(message, status_code: 400, response_body: response_body)
    end
  end

  # Error raised when no local authentication token is found.
  #
  # This error occurs when an operation requires authentication but no token
  # is available in environment variables or the token file.
  #
  # @example
  #   raise LocalTokenNotFoundError.new
  class LocalTokenNotFoundError < DurableHuggingfaceHubError
    # Creates a new local token not found error.
    #
    # @param message [String, nil] Custom error message
    def initialize(message: nil)
      message ||= "No HuggingFace token found. " \
                  "Please login using DurableHuggingfaceHub.login or set the HF_TOKEN environment variable."
      super(message)
    end
  end

  # MARK: - File Operation Errors

  # Error raised when file metadata cannot be retrieved or is invalid.
  #
  # @example
  #   raise FileMetadataError.new("config.json", "Missing ETag header")
  class FileMetadataError < DurableHuggingfaceHubError
    # @return [String] The file path
    attr_reader :path

    # Creates a new file metadata error.
    #
    # @param path [String] File path
    # @param message [String] Error message
    def initialize(path, message)
      @path = path
      super("File metadata error for '#{path}': #{message}")
    end
  end

  # Error raised when the cache directory or cached files are not found.
  #
  # @example
  #   raise CacheNotFoundError.new("/path/to/cache")
  class CacheNotFoundError < DurableHuggingfaceHubError
    # @return [String] The cache path
    attr_reader :cache_path

    # Creates a new cache not found error.
    #
    # @param cache_path [String] Path to cache directory or file
    # @param message [String, nil] Custom error message
    def initialize(cache_path, message: nil)
      @cache_path = cache_path
      message ||= "Cache not found at: #{cache_path}"
      super(message)
    end
  end

  # Error raised when cached files are corrupted or invalid.
  #
  # @example
  #   raise CorruptedCacheError.new("/path/to/file", "Checksum mismatch")
  class CorruptedCacheError < DurableHuggingfaceHubError
    # @return [String] The corrupted file path
    attr_reader :path

    # Creates a new corrupted cache error.
    #
    # @param path [String] Path to corrupted file
    # @param reason [String] Reason for corruption
    def initialize(path, reason)
      @path = path
      super("Corrupted cache file at '#{path}': #{reason}")
    end
  end

  # MARK: - Inference Errors

  # Error raised when an inference request times out.
  #
  # @example
  #   raise InferenceTimeoutError.new("text-generation", 30)
  class InferenceTimeoutError < DurableHuggingfaceHubError
    # @return [String] The task that timed out
    attr_reader :task

    # @return [Integer] Timeout duration in seconds
    attr_reader :timeout

    # Creates a new inference timeout error.
    #
    # @param task [String, nil] Inference task type
    # @param timeout [Integer, nil] Timeout value in seconds
    # @param message [String, nil] Custom error message
    def initialize(task: nil, timeout: nil, message: nil)
      @task = task
      @timeout = timeout
      message ||= build_message
      super(message)
    end

    private

    def build_message
      parts = ["Inference request timed out"]
      parts << "for task '#{task}'" if task
      parts << "after #{timeout} seconds" if timeout
      parts.join(" ")
    end
  end

  # Error raised when an inference endpoint returns an error.
  #
  # @example
  #   raise InferenceEndpointError.new("Model not loaded", status_code: 503)
  class InferenceEndpointError < HfHubHTTPError
    # Creates a new inference endpoint error.
    #
    # @param message [String] Error message
    # @param status_code [Integer, nil] HTTP status code
    # @param response_body [String, nil] Response body
    def initialize(message, status_code: nil, response_body: nil)
      super(message, status_code: status_code, response_body: response_body)
    end
  end

  # MARK: - Validation Errors

  # Error raised when input validation fails.
  #
  # @example
  #   raise ValidationError.new("repo_id", "Invalid format")
  class ValidationError < DurableHuggingfaceHubError
    # @return [String, nil] The field that failed validation
    attr_reader :field

    # Creates a new validation error.
    #
    # @param field [String, nil] Field name
    # @param message [String] Error message
    def initialize(field, message)
      @field = field
      error_msg = field ? "Validation error for '#{field}': #{message}" : "Validation error: #{message}"
      super(error_msg)
    end
  end

  # Error raised when LFS (Large File Storage) operations fail.
  #
  # @example
  #   raise LFSError.new("Upload failed", file: "large_model.bin")
  class LFSError < DurableHuggingfaceHubError
    # @return [String, nil] The file involved in the LFS operation
    attr_reader :file

    # Creates a new LFS error.
    #
    # @param message [String] Error message
    # @param file [String, nil] File path
    def initialize(message, file: nil)
      @file = file
      error_msg = file ? "LFS error for '#{file}': #{message}" : "LFS error: #{message}"
      super(error_msg)
    end
  end
end
