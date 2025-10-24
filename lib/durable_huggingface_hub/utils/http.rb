# frozen_string_literal: true

require "json"
require "faraday"
require "faraday/retry"

require_relative "../configuration"
require_relative "headers"

module DurableHuggingfaceHub
  module Utils
    # HTTP client for making requests to the HuggingFace Hub API.
    #
    # This class provides a configured Faraday client with retry logic,
    # connection pooling, timeout settings, and proper error handling.
    #
    # @example Basic GET request
    #   client = HttpClient.new
    #   response = client.get("https://huggingface.co/api/models/bert-base-uncased")
    #
    # @example With authentication
    #   client = HttpClient.new(token: "hf_...")
    #   response = client.get("/api/whoami")
    class HttpClient
      # @return [String, nil] Authentication token
      attr_reader :token

      # @return [String] Base URL for API requests
      attr_reader :endpoint

      # @return [Hash] Default headers for all requests
      attr_reader :default_headers

      # @return [Faraday::Connection] The underlying Faraday connection
      attr_reader :connection

      # Creates a new HTTP client.
      #
      # @param token [String, nil] Authentication token
      # @param endpoint [String] Base endpoint URL
      # @param headers [Hash, nil] Additional default headers
      # @param timeout [Integer, nil] Request timeout in seconds
      # @param open_timeout [Integer, nil] Connection timeout in seconds
      # @param proxy [String, nil] Proxy URL
      # @param logger [Logger, nil] Logger for request/response logging
      def initialize(
        token: nil,
        endpoint: nil,
        headers: nil,
        timeout: nil,
        open_timeout: nil,
        proxy: nil,
        logger: nil
      )
        @token = token || Configuration.instance.token
        @endpoint = endpoint || Configuration.instance.endpoint
        @default_headers = build_default_headers(headers)
        @logger = logger
        @connection = build_connection(
          timeout: timeout,
          open_timeout: open_timeout,
          proxy: proxy
        )
      end

      # Performs a GET request.
      #
      # @param path [String] URL path or full URL
      # @param params [Hash, nil] Query parameters
      # @param headers [Hash, nil] Additional headers
      # @param timeout [Numeric, nil] Request timeout in seconds
      # @return [Faraday::Response] Response object
      # @raise [HfHubHTTPError] On HTTP errors
      #
      # @example
      #   response = client.get("/api/models", params: { limit: 10 })
      def get(path, params: nil, headers: nil, timeout: nil)
        request(:get, path, params: params, headers: headers, timeout: timeout)
      end

      # Performs a POST request.
      #
      # @param path [String] URL path or full URL
      # @param body [Hash, String, nil] Request body
      # @param params [Hash, nil] Query parameters
      # @param headers [Hash, nil] Additional headers
      # @param timeout [Numeric, nil] Request timeout in seconds
      # @return [Faraday::Response] Response object
      # @raise [HfHubHTTPError] On HTTP errors
      #
      # @example
      #   response = client.post("/api/repos", body: { name: "my-model" })
      def post(path, body: nil, params: nil, headers: nil, timeout: nil)
        request(:post, path, body: body, params: params, headers: headers, timeout: timeout)
      end

      # Performs a PUT request.
      #
      # @param path [String] URL path or full URL
      # @param body [Hash, String, nil] Request body
      # @param params [Hash, nil] Query parameters
      # @param headers [Hash, nil] Additional headers
      # @return [Faraday::Response] Response object
      # @raise [HfHubHTTPError] On HTTP errors
      def put(path, body: nil, params: nil, headers: nil)
        request(:put, path, body: body, params: params, headers: headers)
      end

      # Performs a DELETE request.
      #
      # @param path [String] URL path or full URL
      # @param params [Hash, nil] Query parameters
      # @param headers [Hash, nil] Additional headers
      # @return [Faraday::Response] Response object
      # @raise [HfHubHTTPError] On HTTP errors
      def delete(path, params: nil, headers: nil)
        request(:delete, path, params: params, headers: headers)
      end

      # Performs a HEAD request.
      #
      # @param path [String] URL path or full URL
      # @param params [Hash, nil] Query parameters
      # @param headers [Hash, nil] Additional headers
      # @param timeout [Numeric, nil] Request timeout in seconds
      # @return [Faraday::Response] Response object
      # @raise [HfHubHTTPError] On HTTP errors
      def head(path, params: nil, headers: nil, timeout: nil)
        request(:head, path, params: params, headers: headers, timeout: timeout)
      end

      # Performs an HTTP request with error handling.
      #
      # @param method [Symbol] HTTP method
      # @param path [String] URL path
      # @param body [Hash, String, nil] Request body
      # @param params [Hash, nil] Query parameters
      # @param headers [Hash, nil] Additional headers
      # @param timeout [Numeric, nil] Request timeout in seconds (overrides default)
      # @yield [req] Optional block for Faraday request configuration
      # @return [Faraday::Response] Response object
      # @raise [HfHubHTTPError] On HTTP errors
      def request(method, path, body: nil, params: nil, headers: nil, timeout: nil, &block)
        url = build_url(path)
        merged_headers = @default_headers.merge(headers || {})

        response = @connection.send(method) do |req|
          req.url(url)
          req.params.update(params) if params
          req.headers.update(merged_headers)
          req.body = prepare_body(body) if body && method != :get && method != :head
          req.options.timeout = timeout if timeout
          block&.call(req)
        end

        handle_response(response)
      rescue Faraday::Error => e
        handle_faraday_error(e)
      end

      private

      # Builds the Faraday connection with middleware.
      #
      # @param timeout [Integer, nil] Request timeout
      # @param open_timeout [Integer, nil] Connection timeout
      # @param proxy [String, nil] Proxy URL
      # @return [Faraday::Connection] Configured connection
      def build_connection(timeout: nil, open_timeout: nil, proxy: nil)
        Faraday.new(url: @endpoint) do |conn|
          # Request/response logging (if logger provided)
          if @logger
            conn.response :logger, @logger, { headers: true, bodies: false }
          end

          # Retry middleware with exponential backoff
          conn.request :retry,
                       max: 3,
                       interval: 1,
                       interval_randomness: 0.5,
                       backoff_factor: 2,
                       retry_statuses: [408, 429, 500, 502, 503, 504],
                       methods: %i[get head options delete],
                       exceptions: [
                         Faraday::TimeoutError,
                         Faraday::ConnectionFailed
                       ]

          # JSON request/response handling
          conn.request :json
          conn.response :json, content_type: /\bjson$/

          # Set timeouts
          conn.options.timeout = timeout || Configuration.instance.request_timeout
          conn.options.open_timeout = open_timeout || 10

          # Set proxy if provided
          conn.proxy = proxy if proxy

          # Use default adapter
          conn.adapter Faraday.default_adapter
        end
      end

      # Builds default headers for requests.
      #
      # @param additional_headers [Hash, nil] Additional headers
      # @return [Hash] Complete headers hash
      def build_default_headers(additional_headers)
        Headers.build_hf_headers(
          token: @token,
          headers: additional_headers
        )
      end

       # Builds the full URL from a path.
       #
       # @param path [String] URL path or full URL
       # @return [String] Full URL
       def build_url(path)
         return path if path.start_with?("http://", "https://")

         # Ensure endpoint doesn't end with / and path doesn't start with /
         endpoint = @endpoint.chomp("/")
         path = path.start_with?("/") ? path : "/#{path}"
         "#{endpoint}#{path}"
       end

       # Prepares request body for transmission.
       #
       # @param body [Hash, String] Request body
       # @return [String] Prepared body
       def prepare_body(body)
         return body unless body.is_a?(Hash)

         body.to_json
       end

      # Handles HTTP response and raises errors for non-success status.
      #
      # @param response [Faraday::Response] HTTP response
      # @return [Faraday::Response] Response object if successful
      # @raise [HfHubHTTPError] On error status codes
      def handle_response(response)
        return response if response.success?

        raise_http_error(response)
      end

      # Raises appropriate HTTP error based on response.
      #
      # @param response [Faraday::Response] HTTP response
      # @raise [HfHubHTTPError] Appropriate error subclass
      def raise_http_error(response)
        status = response.status
        body = response.body.is_a?(String) ? response.body : (response.body ? response.body.to_json : nil)
        request_id = Headers.extract_request_id(response.headers)

        case status
        when 400
          raise BadRequestError.new("Bad request", response_body: body)
        when 401
          raise HfHubHTTPError.new("Unauthorized", status_code: 401, response_body: body, request_id: request_id)
        when 403
          # Try to determine if it's gated or disabled
          if body&.include?("gated")
            raise GatedRepoError.new("unknown", message: extract_error_message(body, "Access to this repository is gated"))
          elsif body&.include?("disabled")
            raise DisabledRepoError.new("unknown", message: extract_error_message(body, "Repository has been disabled"))
          else
            raise HfHubHTTPError.new("Forbidden", status_code: 403, response_body: body, request_id: request_id)
          end
        when 404
          raise RepositoryNotFoundError.new("unknown", message: extract_error_message(body, "Repository not found"))
        when 408
          raise HfHubHTTPError.new("Request timeout", status_code: 408, response_body: body, request_id: request_id)
        when 429
          raise HfHubHTTPError.new("Too many requests", status_code: 429, response_body: body, request_id: request_id)
        when 500..599
          raise HfHubHTTPError.new("Server error", status_code: status, response_body: body, request_id: request_id)
        else
          raise HfHubHTTPError.new("HTTP error", status_code: status, response_body: body, request_id: request_id)
        end
      end

      # Extracts error message from response body.
      #
      # @param body [String] Response body
      # @param default [String] Default message
      # @return [String] Error message
      def extract_error_message(body, default)
        return default unless body

        begin
          parsed = JSON.parse(body)
          parsed["error"] || parsed["message"] || default
        rescue JSON::ParserError
          default
        end
      end

      # Handles Faraday errors.
      #
      # @param error [Faraday::Error] Faraday error
      # @raise [HfHubHTTPError] Converted error
      def handle_faraday_error(error)
        case error
        when Faraday::RetriableResponse
          # Retry middleware exhausted retries - extract response and handle as HTTP error
          if error.response && error.response.is_a?(Hash) && error.response[:response]
            raise_http_error(error.response[:response])
          elsif error.response && error.response.respond_to?(:status)
            raise_http_error(error.response)
          else
            raise HfHubHTTPError.new("Retryable error: #{error.message}")
          end
        when Faraday::TimeoutError
          raise HfHubHTTPError.new("Request timed out: #{error.message}")
        when Faraday::ConnectionFailed
          raise HfHubHTTPError.new("Connection failed: #{error.message}")
        when Faraday::SSLError
          raise HfHubHTTPError.new("SSL error: #{error.message}")
        else
          raise HfHubHTTPError.new("HTTP error: #{error.message}")
        end
      end
    end
  end
end
