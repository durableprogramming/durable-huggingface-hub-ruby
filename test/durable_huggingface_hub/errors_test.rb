# frozen_string_literal: true

require "test_helper"

module DurableHuggingfaceHub
  class ErrorsTest < Minitest::Test
    # --- DurableHuggingfaceHubError ---

    def test_base_error_is_standard_error
      assert_kind_of StandardError, DurableHuggingfaceHubError.new("test")
    end

    # --- HfHubHTTPError ---

    def test_http_error_stores_status_code
      err = HfHubHTTPError.new("message", status_code: 404)

      assert_equal 404, err.status_code
    end

    def test_http_error_stores_request_id
      err = HfHubHTTPError.new("message", request_id: "req-123")

      assert_equal "req-123", err.request_id
    end

    def test_http_error_parses_json_server_message
      body = '{"error": "Model not found"}'
      err = HfHubHTTPError.new("message", response_body: body)

      assert_equal "Model not found", err.server_message
    end

    def test_http_error_parses_message_key
      body = '{"message": "Rate limit exceeded"}'
      err = HfHubHTTPError.new("message", response_body: body)

      assert_equal "Rate limit exceeded", err.server_message
    end

    def test_http_error_falls_back_to_raw_body_when_not_json
      body = "Internal Server Error"
      err = HfHubHTTPError.new("message", response_body: body)

      assert_equal "Internal Server Error", err.server_message
    end

    def test_http_error_truncates_long_body
      body = "x" * 300
      err = HfHubHTTPError.new("message", response_body: body)

      assert err.server_message.end_with?("...")
      assert_operator err.server_message.length, :<, 210
    end

    def test_http_error_nil_server_message_for_nil_body
      err = HfHubHTTPError.new("message", response_body: nil)

      assert_nil err.server_message
    end

    def test_http_error_nil_server_message_for_empty_body
      err = HfHubHTTPError.new("message", response_body: "")

      assert_nil err.server_message
    end

    # --- RepositoryNotFoundError ---

    def test_repo_not_found_stores_repo_id
      err = RepositoryNotFoundError.new("bert-base-uncased")

      assert_equal "bert-base-uncased", err.repo_id
    end

    def test_repo_not_found_has_404_status
      err = RepositoryNotFoundError.new("bert-base-uncased")

      assert_equal 404, err.status_code
    end

    def test_repo_not_found_default_message
      err = RepositoryNotFoundError.new("my-model")

      assert_includes err.message, "my-model"
    end

    def test_repo_not_found_custom_message
      err = RepositoryNotFoundError.new("my-model", message: "Custom message")

      assert_equal "Custom message", err.message
    end

    def test_repo_not_found_is_http_error
      assert_kind_of HfHubHTTPError, RepositoryNotFoundError.new("x")
    end

    # --- RevisionNotFoundError ---

    def test_revision_not_found_stores_revision
      err = RevisionNotFoundError.new("my-branch")

      assert_equal "my-branch", err.revision
    end

    def test_revision_not_found_with_repo_id
      err = RevisionNotFoundError.new("main", repo_id: "my-repo")

      assert_equal "my-repo", err.repo_id
      assert_includes err.message, "my-repo"
      assert_includes err.message, "main"
    end

    def test_revision_not_found_has_404_status
      err = RevisionNotFoundError.new("main")

      assert_equal 404, err.status_code
    end

    # --- EntryNotFoundError ---

    def test_entry_not_found_stores_path
      err = EntryNotFoundError.new("config.json")

      assert_equal "config.json", err.path
    end

    def test_entry_not_found_with_repo_and_revision
      err = EntryNotFoundError.new("file.txt", repo_id: "my-repo", revision: "v1")

      assert_includes err.message, "my-repo"
      assert_includes err.message, "v1"
    end

    def test_entry_not_found_has_404_status
      err = EntryNotFoundError.new("file.txt")

      assert_equal 404, err.status_code
    end

    # --- GatedRepoError ---

    def test_gated_repo_error_stores_repo_id
      err = GatedRepoError.new("meta-llama/Llama-2-7b")

      assert_equal "meta-llama/Llama-2-7b", err.repo_id
    end

    def test_gated_repo_error_has_403_status
      err = GatedRepoError.new("meta-llama/Llama-2-7b")

      assert_equal 403, err.status_code
    end

    # --- DisabledRepoError ---

    def test_disabled_repo_error_stores_repo_id
      err = DisabledRepoError.new("disabled/repo")

      assert_equal "disabled/repo", err.repo_id
    end

    def test_disabled_repo_error_has_403_status
      err = DisabledRepoError.new("disabled/repo")

      assert_equal 403, err.status_code
    end

    # --- BadRequestError ---

    def test_bad_request_error_has_400_status
      err = BadRequestError.new("invalid params")

      assert_equal 400, err.status_code
    end

    # --- LocalTokenNotFoundError ---

    def test_local_token_not_found_default_message
      err = LocalTokenNotFoundError.new

      assert_includes err.message, "HuggingFace token"
    end

    def test_local_token_not_found_custom_message
      err = LocalTokenNotFoundError.new(message: "Custom msg")

      assert_equal "Custom msg", err.message
    end

    def test_local_token_not_found_is_base_error
      assert_kind_of DurableHuggingfaceHubError, LocalTokenNotFoundError.new
    end

    # --- ValidationError ---

    def test_validation_error_stores_field
      err = ValidationError.new("repo_id", "invalid format")

      assert_equal "repo_id", err.field
    end

    def test_validation_error_message_includes_field
      err = ValidationError.new("repo_id", "invalid format")

      assert_includes err.message, "repo_id"
      assert_includes err.message, "invalid format"
    end

    def test_validation_error_nil_field
      err = ValidationError.new(nil, "something went wrong")

      assert_nil err.field
      assert_includes err.message, "something went wrong"
    end

    # --- FileMetadataError ---

    def test_file_metadata_error_stores_path
      err = FileMetadataError.new("model.bin", "missing ETag")

      assert_equal "model.bin", err.path
      assert_includes err.message, "model.bin"
    end

    # --- CacheNotFoundError ---

    def test_cache_not_found_stores_path
      err = CacheNotFoundError.new("/cache/path")

      assert_equal "/cache/path", err.cache_path
    end

    # --- CorruptedCacheError ---

    def test_corrupted_cache_error_stores_path
      err = CorruptedCacheError.new("/cache/file", "checksum mismatch")

      assert_equal "/cache/file", err.path
      assert_includes err.message, "checksum mismatch"
    end

    # --- InferenceTimeoutError ---

    def test_inference_timeout_error_stores_task_and_timeout
      err = InferenceTimeoutError.new(task: "text-generation", timeout: 30)

      assert_equal "text-generation", err.task
      assert_equal 30, err.timeout
      assert_includes err.message, "30"
    end

    # --- LFSError ---

    def test_lfs_error_with_file
      err = LFSError.new("upload failed", file: "model.bin")

      assert_equal "model.bin", err.file
      assert_includes err.message, "model.bin"
    end

    def test_lfs_error_without_file
      err = LFSError.new("upload failed")

      assert_nil err.file
      assert_includes err.message, "upload failed"
    end
  end
end
