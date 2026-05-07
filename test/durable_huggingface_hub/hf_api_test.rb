# frozen_string_literal: true

require "test_helper"

module DurableHuggingfaceHub
  class HfApiTest < Minitest::Test
    def setup
      DurableHuggingfaceHub::Configuration.reset!
      @api = build_api
    end

    def teardown
      DurableHuggingfaceHub::Configuration.reset!
      WebMock.reset!
    end

    # --- initialization ---

    def test_initializes_with_token
      api = HfApi.new(token: "hf_custom_token")
      assert_equal "hf_custom_token", api.token
    end

    def test_initializes_with_default_endpoint
      api = HfApi.new(token: "hf_test")
      assert_equal Constants::ENDPOINT, api.endpoint
    end

    def test_initializes_with_custom_endpoint
      api = HfApi.new(token: "hf_test", endpoint: "https://custom.example.com")
      assert_equal "https://custom.example.com", api.endpoint
    end

    def test_http_client_is_initialized
      refute_nil @api.http_client
    end

    # --- model_info ---

    def test_model_info_returns_model_info_object
      stub_hf_get("/api/models/bert-base-uncased", body: model_info_hash)
      info = @api.model_info("bert-base-uncased")
      assert_instance_of Types::ModelInfo, info
    end

    def test_model_info_returns_correct_id
      stub_hf_get("/api/models/bert-base-uncased", body: model_info_hash)
      info = @api.model_info("bert-base-uncased")
      assert_equal "bert-base-uncased", info.id
    end

    def test_model_info_returns_downloads
      stub_hf_get("/api/models/bert-base-uncased", body: model_info_hash)
      info = @api.model_info("bert-base-uncased")
      assert_equal 1_000_000, info.downloads
    end

    def test_model_info_with_revision
      stub_request(:get, "#{TestHelpers::HF_ENDPOINT}/api/models/bert-base-uncased")
        .with(query: hash_including("revision" => "v1.0"))
        .to_return(status: 200, body: model_info_hash.to_json, headers: { "Content-Type" => "application/json" })
      info = @api.model_info("bert-base-uncased", revision: "v1.0")
      assert_equal "bert-base-uncased", info.id
    end

    def test_model_info_raises_on_invalid_repo_id
      assert_raises(ValidationError) { @api.model_info("") }
    end

    def test_model_info_raises_repository_not_found
      stub_hf_get("/api/models/nonexistent/model", body: { "error" => "Not found" }, status: 404)
      assert_raises(RepositoryNotFoundError) { @api.model_info("nonexistent/model") }
    end

    # --- dataset_info ---

    def test_dataset_info_returns_dataset_info_object
      stub_hf_get("/api/datasets/squad", body: dataset_info_hash)
      info = @api.dataset_info("squad")
      assert_instance_of Types::DatasetInfo, info
    end

    def test_dataset_info_returns_correct_id
      stub_hf_get("/api/datasets/squad", body: dataset_info_hash)
      info = @api.dataset_info("squad")
      assert_equal "squad", info.id
    end

    def test_dataset_info_raises_on_not_found
      stub_hf_get("/api/datasets/nonexistent", body: { "error" => "Not found" }, status: 404)
      assert_raises(RepositoryNotFoundError) { @api.dataset_info("nonexistent") }
    end

    # --- space_info ---

    def test_space_info_returns_space_info_object
      stub_hf_get("/api/spaces/stabilityai/stable-diffusion", body: space_info_hash)
      info = @api.space_info("stabilityai/stable-diffusion")
      assert_instance_of Types::SpaceInfo, info
    end

    def test_space_info_returns_correct_id
      stub_hf_get("/api/spaces/stabilityai/stable-diffusion", body: space_info_hash)
      info = @api.space_info("stabilityai/stable-diffusion")
      assert_equal "stabilityai/stable-diffusion", info.id
    end

    # --- repo_info ---

    def test_repo_info_model_type
      stub_hf_get("/api/models/bert-base-uncased", body: model_info_hash)
      info = @api.repo_info("bert-base-uncased", repo_type: "model")
      assert_instance_of Types::ModelInfo, info
    end

    def test_repo_info_dataset_type
      stub_hf_get("/api/datasets/squad", body: dataset_info_hash)
      info = @api.repo_info("squad", repo_type: "dataset")
      assert_instance_of Types::DatasetInfo, info
    end

    def test_repo_info_space_type
      stub_hf_get("/api/spaces/stabilityai/stable-diffusion", body: space_info_hash)
      info = @api.repo_info("stabilityai/stable-diffusion", repo_type: "space")
      assert_instance_of Types::SpaceInfo, info
    end

    def test_repo_info_raises_on_invalid_repo_type
      assert_raises(ValidationError) { @api.repo_info("bert-base-uncased", repo_type: "invalid") }
    end

    def test_repo_info_raises_on_invalid_revision
      assert_raises(ValidationError) { @api.repo_info("bert-base-uncased", revision: "") }
    end

    # --- list_models ---

    def test_list_models_returns_array
      stub_hf_get("/api/models", body: [model_info_hash])
      models = @api.list_models
      assert_instance_of Array, models
    end

    def test_list_models_returns_model_info_objects
      stub_hf_get("/api/models", body: [model_info_hash])
      models = @api.list_models
      assert_instance_of Types::ModelInfo, models.first
    end

    def test_list_models_with_search_param
      stub_request(:get, "#{TestHelpers::HF_ENDPOINT}/api/models")
        .with(query: hash_including("search" => "bert"))
        .to_return(status: 200, body: [model_info_hash].to_json, headers: { "Content-Type" => "application/json" })
      models = @api.list_models(search: "bert")
      assert_equal 1, models.size
    end

    def test_list_models_with_author_param
      stub_request(:get, "#{TestHelpers::HF_ENDPOINT}/api/models")
        .with(query: hash_including("author" => "google"))
        .to_return(status: 200, body: [model_info_hash].to_json, headers: { "Content-Type" => "application/json" })
      models = @api.list_models(author: "google")
      assert_equal 1, models.size
    end

    def test_list_models_with_limit_param
      stub_request(:get, "#{TestHelpers::HF_ENDPOINT}/api/models")
        .with(query: hash_including("limit" => "5"))
        .to_return(status: 200, body: [model_info_hash].to_json, headers: { "Content-Type" => "application/json" })
      models = @api.list_models(limit: 5)
      assert_equal 1, models.size
    end

    def test_list_models_with_string_filter
      stub_request(:get, "#{TestHelpers::HF_ENDPOINT}/api/models")
        .with(query: hash_including("filter" => "text-classification"))
        .to_return(status: 200, body: [model_info_hash].to_json, headers: { "Content-Type" => "application/json" })
      models = @api.list_models(filter: "text-classification")
      assert_equal 1, models.size
    end

    def test_list_models_returns_empty_array_on_no_results
      stub_hf_get("/api/models", body: [])
      models = @api.list_models
      assert_equal [], models
    end

    # --- list_datasets ---

    def test_list_datasets_returns_array
      stub_hf_get("/api/datasets", body: [dataset_info_hash])
      datasets = @api.list_datasets
      assert_instance_of Array, datasets
    end

    def test_list_datasets_returns_dataset_info_objects
      stub_hf_get("/api/datasets", body: [dataset_info_hash])
      datasets = @api.list_datasets
      assert_instance_of Types::DatasetInfo, datasets.first
    end

    # --- list_spaces ---

    def test_list_spaces_returns_array
      stub_hf_get("/api/spaces", body: [space_info_hash])
      spaces = @api.list_spaces
      assert_instance_of Array, spaces
    end

    def test_list_spaces_returns_space_info_objects
      stub_hf_get("/api/spaces", body: [space_info_hash])
      spaces = @api.list_spaces
      assert_instance_of Types::SpaceInfo, spaces.first
    end

    # --- repo_exists ---

    def test_repo_exists_returns_true_when_found
      stub_hf_get("/api/models/bert-base-uncased", body: model_info_hash)
      assert @api.repo_exists("bert-base-uncased")
    end

    def test_repo_exists_returns_false_when_not_found
      stub_hf_get("/api/models/nonexistent/model", body: { "error" => "Not found" }, status: 404)
      refute @api.repo_exists("nonexistent/model")
    end

    def test_repo_exists_for_dataset
      stub_hf_get("/api/datasets/squad", body: dataset_info_hash)
      assert @api.repo_exists("squad", repo_type: "dataset")
    end

    # --- whoami ---

    def test_whoami_returns_user_object
      stub_hf_get("/api/whoami-v2", body: user_hash)
      user = @api.whoami
      assert_instance_of Types::User, user
    end

    def test_whoami_returns_correct_name
      stub_hf_get("/api/whoami-v2", body: user_hash)
      user = @api.whoami
      assert_equal "test-user", user.name
    end

    def test_whoami_raises_on_unauthorized
      stub_hf_get("/api/whoami-v2", body: { "error" => "Unauthorized" }, status: 401)
      assert_raises(HfHubHTTPError) { @api.whoami }
    end

    # --- list_repo_files ---

    def test_list_repo_files_returns_array_of_paths
      file_tree = [
        { "path" => "config.json", "type" => "file" },
        { "path" => "pytorch_model.bin", "type" => "file" }
      ]
      stub_request(:get, "#{TestHelpers::HF_ENDPOINT}/api/models/bert-base-uncased/tree")
        .with(query: hash_including("recursive" => "true"))
        .to_return(status: 200, body: file_tree.to_json, headers: { "Content-Type" => "application/json" })
      files = @api.list_repo_files(repo_id: "bert-base-uncased")
      assert_includes files, "config.json"
      assert_includes files, "pytorch_model.bin"
    end

    def test_list_repo_files_raises_on_invalid_repo_id
      assert_raises(ValidationError) { @api.list_repo_files(repo_id: "") }
    end

    # --- list_repo_tree ---

    def test_list_repo_tree_returns_hash
      tree_data = [{ "path" => "config.json", "size" => 512 }]
      stub_request(:get, "#{TestHelpers::HF_ENDPOINT}/api/models/bert-base-uncased/tree")
        .with(query: hash_including("revision" => "main"))
        .to_return(status: 200, body: tree_data.to_json, headers: { "Content-Type" => "application/json" })
      result = @api.list_repo_tree(repo_id: "bert-base-uncased")
      assert_instance_of Hash, result
      assert result.key?("config.json")
    end

    def test_list_repo_tree_nested_paths
      tree_data = [
        { "path" => "models/model.bin", "size" => 1024 }
      ]
      stub_request(:get, "#{TestHelpers::HF_ENDPOINT}/api/models/my-org/my-model/tree")
        .with(query: hash_including("revision" => "main"))
        .to_return(status: 200, body: tree_data.to_json, headers: { "Content-Type" => "application/json" })
      result = @api.list_repo_tree(repo_id: "my-org/my-model")
      assert result.key?("models")
      assert_equal "directory", result["models"][:type]
    end

    # --- build_tree_structure ---

    def test_build_tree_structure_single_file
      items = [{ "path" => "config.json", "size" => 512 }]
      tree = @api.build_tree_structure(items)
      assert_equal "file", tree["config.json"][:type]
      assert_equal 512, tree["config.json"][:size]
    end

    def test_build_tree_structure_nested_path
      items = [{ "path" => "models/weights.bin", "size" => 1024 }]
      tree = @api.build_tree_structure(items)
      assert_equal "directory", tree["models"][:type]
      assert_equal "file", tree["models"][:children]["weights.bin"][:type]
    end

    def test_build_tree_structure_multiple_files
      items = [
        { "path" => "config.json", "size" => 100 },
        { "path" => "model.bin", "size" => 200 }
      ]
      tree = @api.build_tree_structure(items)
      assert tree.key?("config.json")
      assert tree.key?("model.bin")
    end

    # --- delete_repo ---

    def test_delete_repo_returns_true
      stub_request(:delete, /#{Regexp.escape(TestHelpers::HF_ENDPOINT + "/api/models/test-user/my-model")}/)
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
      assert @api.delete_repo(repo_id: "test-user/my-model")
    end

    def test_delete_repo_raises_on_invalid_repo_id
      assert_raises(ValidationError) { @api.delete_repo(repo_id: "") }
    end

    # --- file_exists ---

    def test_file_exists_returns_true_when_found
      stub_request(:head, "#{TestHelpers::HF_ENDPOINT}/api/models/bert-base-uncased/resolve/main/config.json")
        .to_return(status: 200)
      assert @api.file_exists(repo_id: "bert-base-uncased", path_in_repo: "config.json")
    end

    def test_file_exists_returns_false_when_not_found
      stub_request(:head, /#{Regexp.escape(TestHelpers::HF_ENDPOINT + "/api/models/bert-base-uncased/resolve/main/missing.json")}/)
        .to_return(status: 404)
      refute @api.file_exists(repo_id: "bert-base-uncased", path_in_repo: "missing.json")
    end

    # --- HTTP error handling ---

    def test_raises_hf_hub_http_error_on_500
      stub_hf_get("/api/models/bert-base-uncased", body: { "error" => "Internal Server Error" }, status: 500)
      assert_raises(HfHubHTTPError) { @api.model_info("bert-base-uncased") }
    end

    def test_raises_hf_hub_http_error_on_429
      stub_hf_get("/api/models/bert-base-uncased", body: { "error" => "Too many requests" }, status: 429)
      err = assert_raises(HfHubHTTPError) { @api.model_info("bert-base-uncased") }
      assert_equal 429, err.status_code
    end

    def test_raises_gated_repo_error_on_403_gated
      stub_hf_get("/api/models/gated/model", body: { "error" => "This repo is gated" }, status: 403)
      assert_raises(GatedRepoError) { @api.model_info("gated/model") }
    end

    # --- update_repo_visibility ---

    def test_update_repo_visibility_returns_true
      stub_request(:post, "#{TestHelpers::HF_ENDPOINT}/api/models/test-user/my-model/settings")
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
      assert @api.update_repo_visibility(repo_id: "test-user/my-model", private: true)
    end

    # --- move_repo ---

    def test_move_repo_returns_true
      stub_request(:post, "#{TestHelpers::HF_ENDPOINT}/api/models/old-user/old-model/move")
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
      assert @api.move_repo(from_repo_id: "old-user/old-model", to_repo_id: "new-user/new-model")
    end

    def test_move_repo_raises_on_invalid_from_id
      assert_raises(ValidationError) { @api.move_repo(from_repo_id: "", to_repo_id: "new-user/new-model") }
    end

    def test_move_repo_raises_on_invalid_to_id
      assert_raises(ValidationError) { @api.move_repo(from_repo_id: "old-user/old-model", to_repo_id: "") }
    end

    # --- delete_branch ---

    def test_delete_branch_returns_true
      stub_request(:delete, /#{Regexp.escape(TestHelpers::HF_ENDPOINT + "/api/models/test-user/my-model/branches/my-branch")}/)
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
      assert @api.delete_branch(repo_id: "test-user/my-model", branch_name: "my-branch")
    end

    # --- delete_tag ---

    def test_delete_tag_returns_true
      stub_request(:delete, /#{Regexp.escape(TestHelpers::HF_ENDPOINT + "/api/models/test-user/my-model/tags/v1.0")}/)
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
      assert @api.delete_tag(repo_id: "test-user/my-model", tag_name: "v1.0")
    end

    # --- get_paths_info ---

    def test_get_paths_info_returns_array
      stub_request(:head, "#{TestHelpers::HF_ENDPOINT}/api/models/bert-base-uncased/resolve/main/config.json")
        .to_return(status: 200, headers: {
          "x-linked-size" => "1024",
          "etag" => '"abc123"',
          "x-repo-commit" => "def456",
          "Content-Type" => "application/json"
        })
      result = @api.get_paths_info(repo_id: "bert-base-uncased", paths: ["config.json"])
      assert_instance_of Array, result
      assert_equal 1, result.size
    end

    def test_get_paths_info_returns_nil_for_missing_file
      stub_request(:head, "#{TestHelpers::HF_ENDPOINT}/api/models/bert-base-uncased/resolve/main/missing.bin")
        .to_return(status: 404)
      result = @api.get_paths_info(repo_id: "bert-base-uncased", paths: ["missing.bin"])
      assert_equal [nil], result
    end

    def test_get_paths_info_raises_on_non_array_paths
      assert_raises(ArgumentError) { @api.get_paths_info(repo_id: "bert-base-uncased", paths: "config.json") }
    end
  end
end
