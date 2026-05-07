# frozen_string_literal: true

require "test_helper"

module DurableHuggingfaceHub
  module Utils
    class HttpClientTest < Minitest::Test
      ENDPOINT = "https://huggingface.co"

      def setup
        DurableHuggingfaceHub::Configuration.reset!
        @client = HttpClient.new(token: "hf_test_token", endpoint: ENDPOINT)
      end

      def teardown
        DurableHuggingfaceHub::Configuration.reset!
        WebMock.reset!
      end

      # --- basic requests ---

      def test_get_returns_response_on_success
        stub_request(:get, "#{ENDPOINT}/api/models")
          .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })
        response = @client.get("/api/models")
        assert_equal 200, response.status
      end

      def test_post_sends_request
        stub_request(:post, "#{ENDPOINT}/api/repos/create")
          .to_return(status: 200, body: '{"url":"https://huggingface.co/test/repo"}',
                     headers: { "Content-Type" => "application/json" })
        response = @client.post("/api/repos/create", body: { name: "repo" })
        assert_equal 200, response.status
      end

      def test_head_sends_head_request
        stub_request(:head, "#{ENDPOINT}/api/models/bert-base-uncased/resolve/main/config.json")
          .to_return(status: 200, headers: { "Content-Type" => "application/json" })
        response = @client.head("/api/models/bert-base-uncased/resolve/main/config.json")
        assert_equal 200, response.status
      end

      def test_delete_sends_delete_request
        stub_request(:delete, "#{ENDPOINT}/api/models/test-user/my-model")
          .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
        response = @client.delete("/api/models/test-user/my-model")
        assert_equal 200, response.status
      end

      # --- URL building ---

      def test_builds_full_url_from_path
        stub_request(:get, "#{ENDPOINT}/api/test")
          .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
        @client.get("/api/test")
        assert_requested :get, "#{ENDPOINT}/api/test"
      end

      def test_passes_through_full_url
        stub_request(:get, "https://example.com/api/test")
          .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
        @client.get("https://example.com/api/test")
        assert_requested :get, "https://example.com/api/test"
      end

      # --- error handling ---

      def test_raises_repository_not_found_on_404
        stub_request(:get, "#{ENDPOINT}/api/models/nonexistent")
          .to_return(status: 404, body: '{"error":"Not found"}', headers: { "Content-Type" => "application/json" })
        assert_raises(RepositoryNotFoundError) { @client.get("/api/models/nonexistent") }
      end

      def test_raises_bad_request_on_400
        stub_request(:get, "#{ENDPOINT}/api/test")
          .to_return(status: 400, body: '{"error":"Bad request"}', headers: { "Content-Type" => "application/json" })
        assert_raises(BadRequestError) { @client.get("/api/test") }
      end

      def test_raises_http_error_on_401
        stub_request(:get, "#{ENDPOINT}/api/test")
          .to_return(status: 401, body: '{"error":"Unauthorized"}', headers: { "Content-Type" => "application/json" })
        err = assert_raises(HfHubHTTPError) { @client.get("/api/test") }
        assert_equal 401, err.status_code
      end

      def test_raises_gated_repo_error_on_403_with_gated_body
        stub_request(:get, "#{ENDPOINT}/api/test")
          .to_return(status: 403, body: '{"error":"This repo is gated"}', headers: { "Content-Type" => "application/json" })
        assert_raises(GatedRepoError) { @client.get("/api/test") }
      end

      def test_raises_disabled_repo_error_on_403_with_disabled_body
        stub_request(:get, "#{ENDPOINT}/api/test")
          .to_return(status: 403, body: '{"error":"This repo is disabled"}', headers: { "Content-Type" => "application/json" })
        assert_raises(DisabledRepoError) { @client.get("/api/test") }
      end

      def test_raises_http_error_on_500
        stub_request(:get, "#{ENDPOINT}/api/test")
          .to_return(status: 500, body: '{"error":"Server error"}', headers: { "Content-Type" => "application/json" })
        err = assert_raises(HfHubHTTPError) { @client.get("/api/test") }
        assert_equal 500, err.status_code
      end

      def test_raises_http_error_on_429
        stub_request(:get, "#{ENDPOINT}/api/test")
          .to_return(status: 429, body: '{"error":"Too many requests"}', headers: { "Content-Type" => "application/json" })
        err = assert_raises(HfHubHTTPError) { @client.get("/api/test") }
        assert_equal 429, err.status_code
      end

      # --- query params ---

      def test_passes_query_params
        stub_request(:get, "#{ENDPOINT}/api/models")
          .with(query: { "limit" => "10", "search" => "bert" })
          .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })
        response = @client.get("/api/models", params: { limit: 10, search: "bert" })
        assert_equal 200, response.status
      end

      # --- authentication headers ---

      def test_sends_authorization_header
        stub_request(:get, "#{ENDPOINT}/api/whoami-v2")
          .with(headers: { "Authorization" => "Bearer hf_test_token" })
          .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
        @client.get("/api/whoami-v2")
        assert_requested :get, "#{ENDPOINT}/api/whoami-v2",
                         headers: { "Authorization" => "Bearer hf_test_token" }
      end

      def test_no_auth_header_without_token
        orig_token = ENV.delete("HF_TOKEN")
        orig_legacy = ENV.delete("HUGGING_FACE_HUB_TOKEN")
        DurableHuggingfaceHub::Configuration.reset!
        client = HttpClient.new(token: nil, endpoint: ENDPOINT)
        stub_request(:get, "#{ENDPOINT}/api/public")
          .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
        client.get("/api/public")
        assert_not_requested :get, "#{ENDPOINT}/api/public",
                             headers: { "Authorization" => /Bearer/ }
      ensure
        ENV["HF_TOKEN"] = orig_token if orig_token
        ENV["HUGGING_FACE_HUB_TOKEN"] = orig_legacy if orig_legacy
        DurableHuggingfaceHub::Configuration.reset!
      end
    end
  end
end
