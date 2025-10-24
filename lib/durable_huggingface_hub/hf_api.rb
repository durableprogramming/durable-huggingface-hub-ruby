# frozen_string_literal: true

require "faraday"
require "faraday/multipart"
require_relative "constants"
require_relative "configuration"
require_relative "utils/http"
require_relative "utils/auth"
require_relative "utils/validators"
require_relative "types"

module DurableHuggingfaceHub
  # Main API client for interacting with the HuggingFace Hub
  #
  # This class provides methods for accessing and managing repositories,
  # models, datasets, and spaces on the HuggingFace Hub. It handles
  # authentication, request management, and response parsing.
  #
  # @example Initialize with default configuration
  #   api = DurableHuggingfaceHub::HfApi.new
  #
  # @example Initialize with custom token and endpoint
  #   api = DurableHuggingfaceHub::HfApi.new(
  #     token: "hf_...",
  #     endpoint: "https://huggingface.co"
  #   )
  #
  # @example Get model information
  #   model = api.model_info("bert-base-uncased")
  #   puts model.id
  #   puts model.downloads
  #
  # @example List models with filtering
  #   models = api.list_models(filter: "text-classification", limit: 10)
  #   models.each { |m| puts m.id }
  class HfApi
    # @return [String, nil] Authentication token for API requests
    attr_reader :token

    # @return [String] Base endpoint URL for the HuggingFace Hub
    attr_reader :endpoint

    # @return [DurableHuggingfaceHub::Utils::HttpClient] HTTP client instance
    attr_reader :http_client

    # Initialize a new HfApi client
    #
    # @param token [String, nil] HuggingFace authentication token.
    #   If nil, will attempt to retrieve from environment or token file.
    # @param endpoint [String, nil] Base URL for the HuggingFace Hub API.
    #   Defaults to {DurableHuggingfaceHub::Constants::ENDPOINT}.
    #
    # @example Create client with auto-detected token
    #   api = DurableHuggingfaceHub::HfApi.new
    #
    # @example Create client with explicit token
    #   api = DurableHuggingfaceHub::HfApi.new(token: "hf_...")
    #
    # @example Create client with custom endpoint
    #   api = DurableHuggingfaceHub::HfApi.new(
    #     endpoint: "https://custom-hub.example.com"
    #   )
    def initialize(token: nil, endpoint: nil)
      @token = token || DurableHuggingfaceHub::Utils::Auth.get_token
      @endpoint = endpoint || DurableHuggingfaceHub.configuration.endpoint
      @http_client = DurableHuggingfaceHub::Utils::HttpClient.new(
        endpoint: @endpoint,
        token: @token
      )
    end

    # Get comprehensive information about a repository
    #
    # This is a generic method that works for any repository type (model,
    # dataset, or space). For type-specific methods, see {#model_info},
    # {#dataset_info}, or {#space_info}.
    #
    # @param repo_id [String] Repository identifier in the format "namespace/name"
    #   or just "name" for repositories in your namespace
    # @param repo_type [String, Symbol] Type of repository: "model", "dataset", or "space"
    # @param revision [String, nil] Git revision (branch, tag, or commit SHA).
    #   Defaults to "main"
    # @param timeout [Numeric, nil] Request timeout in seconds
    #
    # @return [DurableHuggingfaceHub::Types::ModelInfo, DurableHuggingfaceHub::Types::DatasetInfo, DurableHuggingfaceHub::Types::SpaceInfo]
    #   Repository information object, type depends on repo_type
    #
    # @raise [ArgumentError] If repo_id or repo_type is invalid
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If repository doesn't exist
    # @raise [DurableHuggingfaceHub::RevisionNotFoundError] If revision doesn't exist
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors
    #
    # @example Get model information
    #   info = api.repo_info("bert-base-uncased", repo_type: "model")
    #   puts info.id
    #   puts info.downloads
    #
    # @example Get dataset information with specific revision
    #   info = api.repo_info("squad", repo_type: "dataset", revision: "v1.0")
    #   puts info.id
    #
    # @example Get space information
    #   info = api.repo_info("stabilityai/stable-diffusion", repo_type: "space")
    #   puts info.id
    def repo_info(repo_id, repo_type: "model", revision: nil, timeout: nil)
      # Validate inputs
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)

      if revision
        DurableHuggingfaceHub::Utils::Validators.validate_revision(revision)
      end

      # Build API path
      path = case repo_type.to_s
             when "model"
               "/api/models/#{repo_id}"
             when "dataset"
               "/api/datasets/#{repo_id}"
             when "space"
               "/api/spaces/#{repo_id}"
             else
               raise ArgumentError, "Invalid repo_type: #{repo_type}"
             end

      # Add revision if specified
      params = {}
      params[:revision] = revision if revision

      # Make request
       response = http_client.get(path, params: params, timeout: timeout)

       # Parse response based on repo_type
       body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
       case repo_type.to_s
       when "model"
         DurableHuggingfaceHub::Types::ModelInfo.from_hash(body)
       when "dataset"
         DurableHuggingfaceHub::Types::DatasetInfo.from_hash(body)
       when "space"
         DurableHuggingfaceHub::Types::SpaceInfo.from_hash(body)
       end
    end

    # Get information about a specific model
    #
    # This is a convenience method that calls {#repo_info} with
    # repo_type: "model".
    #
    # @param repo_id [String] Model repository identifier
    # @param revision [String, nil] Git revision (branch, tag, or commit SHA).
    #   Defaults to "main"
    # @param timeout [Numeric, nil] Request timeout in seconds
    #
    # @return [DurableHuggingfaceHub::Types::ModelInfo] Model information
    #
    # @raise [ArgumentError] If repo_id is invalid
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If model doesn't exist
    # @raise [DurableHuggingfaceHub::RevisionNotFoundError] If revision doesn't exist
    #
    # @example Get basic model info
    #   model = api.model_info("bert-base-uncased")
    #   puts "Downloads: #{model.downloads}"
    #   puts "Likes: #{model.likes}"
    #
    # @example Get model info for specific revision
    #   model = api.model_info("gpt2", revision: "main")
    #   puts "SHA: #{model.sha}"
    def model_info(repo_id, revision: nil, timeout: nil)
      repo_info(repo_id, repo_type: "model", revision: revision, timeout: timeout)
    end

    # Get information about a specific dataset
    #
    # This is a convenience method that calls {#repo_info} with
    # repo_type: "dataset".
    #
    # @param repo_id [String] Dataset repository identifier
    # @param revision [String, nil] Git revision (branch, tag, or commit SHA).
    #   Defaults to "main"
    # @param timeout [Numeric, nil] Request timeout in seconds
    #
    # @return [DurableHuggingfaceHub::Types::DatasetInfo] Dataset information
    #
    # @raise [ArgumentError] If repo_id is invalid
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If dataset doesn't exist
    # @raise [DurableHuggingfaceHub::RevisionNotFoundError] If revision doesn't exist
    #
    # @example Get dataset info
    #   dataset = api.dataset_info("squad")
    #   puts "Downloads: #{dataset.downloads}"
    #   puts "Tags: #{dataset.tags}"
    def dataset_info(repo_id, revision: nil, timeout: nil)
      repo_info(repo_id, repo_type: "dataset", revision: revision, timeout: timeout)
    end

    # Get information about a specific space
    #
    # This is a convenience method that calls {#repo_info} with
    # repo_type: "space".
    #
    # @param repo_id [String] Space repository identifier
    # @param revision [String, nil] Git revision (branch, tag, or commit SHA).
    #   Defaults to "main"
    # @param timeout [Numeric, nil] Request timeout in seconds
    #
    # @return [DurableHuggingfaceHub::Types::SpaceInfo] Space information
    #
    # @raise [ArgumentError] If repo_id is invalid
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If space doesn't exist
    # @raise [DurableHuggingfaceHub::RevisionNotFoundError] If revision doesn't exist
    #
    # @example Get space info
    #   space = api.space_info("stabilityai/stable-diffusion")
    #   puts "Runtime: #{space.runtime}"
    #   puts "SDK: #{space.sdk}"
    def space_info(repo_id, revision: nil, timeout: nil)
      repo_info(repo_id, repo_type: "space", revision: revision, timeout: timeout)
    end

    # List models from the HuggingFace Hub with optional filtering
    #
    # Returns a list of models matching the specified criteria. Results can be
    # filtered by tags, author, search query, and sorted by various metrics.
    #
    # @param filter [String, Hash, nil] Filter criteria:
    #   - String: Search query or single tag
    #   - Hash: Structured filters (e.g., {author: "google", task: "text-classification"})
    # @param author [String, nil] Filter by author/organization
    # @param search [String, nil] Search query for model names and descriptions
    # @param sort [String, Symbol, nil] Sort criterion:
    #   "downloads", "likes", "updated", "created", "trending"
    # @param direction [Integer, nil] Sort direction: -1 for descending, 1 for ascending
    # @param limit [Integer, nil] Maximum number of results to return
    # @param full [Boolean] If true, fetch full model information (slower)
    # @param timeout [Numeric, nil] Request timeout in seconds
    #
    # @return [Array<DurableHuggingfaceHub::Types::ModelInfo>] List of models
    #
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For API errors
    #
    # @example List all models
    #   models = api.list_models
    #
    # @example List models by author
    #   models = api.list_models(author: "google")
    #
    # @example Search for specific models
    #   models = api.list_models(search: "bert")
    #
    # @example Filter by task and sort by downloads
    #   models = api.list_models(
    #     filter: {task: "text-classification"},
    #     sort: "downloads",
    #     direction: -1,
    #     limit: 10
    #   )
    #
    # @example Filter by multiple criteria
    #   models = api.list_models(
    #     filter: {
    #       author: "facebook",
    #       library: "pytorch",
    #       language: "en"
    #     },
    #     limit: 20
    #   )
    def list_models(filter: nil, author: nil, search: nil, sort: nil,
                    direction: nil, limit: nil, full: false, timeout: nil)
      path = "/api/models"
      params = build_list_params(
        filter: filter,
        author: author,
        search: search,
        sort: sort,
        direction: direction,
        limit: limit,
        full: full
      )

       response = http_client.get(path, params: params, timeout: timeout)

       # Response is an array of model objects
       body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
       body.map { |model_data| DurableHuggingfaceHub::Types::ModelInfo.from_hash(model_data) }
    end

    # List datasets from the HuggingFace Hub with optional filtering
    #
    # Returns a list of datasets matching the specified criteria.
    #
    # @param filter [String, Hash, nil] Filter criteria
    # @param author [String, nil] Filter by author/organization
    # @param search [String, nil] Search query
    # @param sort [String, Symbol, nil] Sort criterion
    # @param direction [Integer, nil] Sort direction: -1 for descending, 1 for ascending
    # @param limit [Integer, nil] Maximum number of results
    # @param full [Boolean] Fetch full dataset information
    # @param timeout [Numeric, nil] Request timeout in seconds
    #
    # @return [Array<DurableHuggingfaceHub::Types::DatasetInfo>] List of datasets
    #
    # @example List popular datasets
    #   datasets = api.list_datasets(sort: "downloads", limit: 10)
    def list_datasets(filter: nil, author: nil, search: nil, sort: nil,
                      direction: nil, limit: nil, full: false, timeout: nil)
      path = "/api/datasets"
      params = build_list_params(
        filter: filter,
        author: author,
        search: search,
        sort: sort,
        direction: direction,
        limit: limit,
        full: full
      )

       response = http_client.get(path, params: params, timeout: timeout)
       body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
       body.map { |dataset_data| DurableHuggingfaceHub::Types::DatasetInfo.from_hash(dataset_data) }
    end

    # List spaces from the HuggingFace Hub with optional filtering
    #
    # Returns a list of spaces matching the specified criteria.
    #
    # @param filter [String, Hash, nil] Filter criteria
    # @param author [String, nil] Filter by author/organization
    # @param search [String, nil] Search query
    # @param sort [String, Symbol, nil] Sort criterion
    # @param direction [Integer, nil] Sort direction: -1 for descending, 1 for ascending
    # @param limit [Integer, nil] Maximum number of results
    # @param full [Boolean] Fetch full space information
    # @param timeout [Numeric, nil] Request timeout in seconds
    #
    # @return [Array<DurableHuggingfaceHub::Types::SpaceInfo>] List of spaces
    #
    # @example List trending spaces
    #   spaces = api.list_spaces(sort: "trending", limit: 10)
    def list_spaces(filter: nil, author: nil, search: nil, sort: nil,
                    direction: nil, limit: nil, full: false, timeout: nil)
      path = "/api/spaces"
      params = build_list_params(
        filter: filter,
        author: author,
        search: search,
        sort: sort,
        direction: direction,
        limit: limit,
        full: full
      )

       response = http_client.get(path, params: params, timeout: timeout)
       body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
       body.map { |space_data| DurableHuggingfaceHub::Types::SpaceInfo.from_hash(space_data) }
    end

    # Check if a repository exists on the HuggingFace Hub
    #
    # @param repo_id [String] Repository identifier
    # @param repo_type [String, Symbol] Type of repository: "model", "dataset", or "space"
    # @param timeout [Numeric, nil] Request timeout in seconds
    #
    # @return [Boolean] True if repository exists, false otherwise
    #
    # @example Check if model exists
    #   if api.repo_exists("bert-base-uncased")
    #     puts "Model exists!"
    #   end
    def repo_exists(repo_id, repo_type: "model", timeout: nil)
      repo_info(repo_id, repo_type: repo_type, timeout: timeout)
      true
    rescue DurableHuggingfaceHub::RepositoryNotFoundError
      false
    end

    # Get current user information (requires authentication)
    #
    # Returns information about the authenticated user. Requires a valid
    # authentication token.
    #
    # @param timeout [Numeric, nil] Request timeout in seconds
    #
    # @return [DurableHuggingfaceHub::Types::User] User information
    #
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] If not authenticated or token is invalid
    #
    # @example Get current user info
    #   user = api.whoami
    #   puts "Logged in as: #{user.name}"
    #   puts "Type: #{user.type}"
     def whoami(timeout: nil)
       path = "/api/whoami-v2"
       response = http_client.get(path, timeout: timeout)
       body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
       DurableHuggingfaceHub::Types::User.from_hash(body)
     end

    # List files in a repository.
    #
    # @param repo_id [String] Repository ID
    # @param repo_type [String, Symbol] Type of repository ("model", "dataset", or "space")
    # @param revision [String, nil] Git revision (branch, tag, or commit SHA). Defaults to "main"
    # @param timeout [Numeric, nil] Request timeout in seconds
    # @return [Array<String>] List of file paths in the repository
    # @raise [RepositoryNotFoundError] If repository doesn't exist
    # @raise [RevisionNotFoundError] If revision doesn't exist
     def list_repo_files(repo_id:, repo_type: "model", revision: nil, timeout: nil)
       DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
       repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)
       revision = DurableHuggingfaceHub::Utils::Validators.validate_revision(revision) if revision

       path = "/api/#{repo_type}s/#{repo_id}/tree"
       params = { recursive: true }
       params[:revision] = revision if revision

       response = http_client.get(path, params: params, timeout: timeout)
       body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
       body.map { |file_data| file_data["path"] }
     end

    # List repository contents in a hierarchical tree structure.
    #
    # This method provides a tree-like view of the repository contents,
    # organized by directories and files with their metadata.
    #
    # @param repo_id [String] Repository ID
    # @param repo_type [String, Symbol] Type of repository ("model", "dataset", or "space")
    # @param revision [String, nil] Git revision (branch, tag, or commit SHA). Defaults to "main"
    # @param path [String, nil] Path within repository to list (for subdirectories)
    # @param recursive [Boolean] Whether to recursively list subdirectories. Defaults to false
    # @param timeout [Numeric, nil] Request timeout in seconds
    # @return [Hash] Tree structure with directories and files
    # @raise [RepositoryNotFoundError] If repository doesn't exist
    # @raise [RevisionNotFoundError] If revision doesn't exist
    #
    # @example Get repository tree
    #   tree = api.list_repo_tree(repo_id: "bert-base-uncased")
    #   puts tree.keys # ["config.json", "pytorch_model.bin", "tokenizer.json", ...]
    #
    # @example Get tree for a subdirectory
    #   subtree = api.list_repo_tree(
    #     repo_id: "my-model",
    #     path: "checkpoints"
    #   )
    def list_repo_tree(repo_id:, repo_type: "model", revision: nil, path: nil, recursive: false, timeout: nil)
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)
      revision = DurableHuggingfaceHub::Utils::Validators.validate_revision(revision) if revision
      revision ||= "main"

      # Build the API path
      api_path = "/api/#{repo_type}s/#{repo_id}/tree"
      api_path += "/#{path}" if path

      params = { recursive: recursive }
      params[:revision] = revision if revision

       response = http_client.get(api_path, params: params, timeout: timeout)

       # Organize the response into a tree structure
       body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
       build_tree_structure(body)
    end

    # Get metadata about a file in a repository without downloading it.
    #
    # This method retrieves file metadata including size, ETag, and other information
    # from the HuggingFace Hub API without downloading the actual file content.
    #
    # @param repo_id [String] The ID of the repository.
    # @param filename [String] The path to the file within the repository.
    # @param repo_type [String, Symbol] The type of the repository. Defaults to "model".
    # @param revision [String, nil] The Git revision (branch, tag, or commit SHA). Defaults to "main".
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [Hash] File metadata including :size, :etag, :commit_hash, :last_modified, etc.
    # @raise [ArgumentError] If repo_id, filename, or repo_type is invalid.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the repository does not exist.
    # @raise [DurableHuggingfaceHub::EntryNotFoundError] If the file does not exist.
    # @raise [DurableHuggingfaceHub::RevisionNotFoundError] If the revision does not exist.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors.
    #
    # @example Get metadata for a model file
    #   metadata = api.get_hf_file_metadata(
    #     repo_id: "bert-base-uncased",
    #     filename: "config.json"
    #   )
    #   puts "Size: #{metadata[:size]} bytes"
    #   puts "ETag: #{metadata[:etag]}"
    def get_hf_file_metadata(repo_id:, filename:, repo_type: "model", revision: nil, timeout: nil)
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      DurableHuggingfaceHub::Utils::Validators.validate_filename(filename)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)
      revision = DurableHuggingfaceHub::Utils::Validators.validate_revision(revision) if revision
      revision ||= "main"

      path = "/api/#{repo_type}s/#{repo_id}/resolve/#{revision}/#{filename}"

      begin
        response = http_client.head(path, timeout: timeout)

        # Extract metadata from response headers
        headers = response.headers
        {
          size: headers["x-linked-size"]&.to_i,
          etag: DurableHuggingfaceHub::FileDownload.extract_etag(headers["etag"] || headers["x-linked-etag"]),
          commit_hash: headers["x-repo-commit"],
          last_modified: headers["last-modified"] ? Time.parse(headers["last-modified"]) : nil,
          content_type: headers["content-type"],
          filename: filename,
          repo_id: repo_id,
          repo_type: repo_type,
          revision: revision
        }.compact
      rescue DurableHuggingfaceHub::EntryNotFoundError
        raise
      rescue DurableHuggingfaceHub::HfHubHTTPError => e
        # Convert 404 to EntryNotFoundError for consistency
        if e.status_code == 404
          raise DurableHuggingfaceHub::EntryNotFoundError.new(
            "File #{filename} not found in #{repo_id}@#{revision}"
          )
        end
        raise
      end
    end

    # Get metadata for multiple paths in a repository.
    #
    # This method efficiently retrieves metadata for multiple files or paths
    # in a repository using batch requests where possible.
    #
    # @param repo_id [String] The ID of the repository.
    # @param paths [Array<String>] Array of file paths within the repository.
    # @param repo_type [String, Symbol] The type of the repository. Defaults to "model".
    # @param revision [String, nil] The Git revision (branch, tag, or commit SHA). Defaults to "main".
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [Array<Hash>] Array of metadata hashes, one for each path. Missing files return nil.
    # @raise [ArgumentError] If repo_id, paths, or repo_type is invalid.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the repository does not exist.
    # @raise [DurableHuggingfaceHub::RevisionNotFoundError] If the revision does not exist.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors.
    #
    # @example Get metadata for multiple files
    #   paths = ["config.json", "pytorch_model.bin", "tokenizer.json"]
    #   metadata_list = api.get_paths_info(
    #     repo_id: "bert-base-uncased",
    #     paths: paths
    #   )
    #   metadata_list.each_with_index do |metadata, i|
    #     if metadata
    #       puts "#{paths[i]}: #{metadata[:size]} bytes"
    #     else
    #       puts "#{paths[i]}: not found"
    #     end
    #   end
    def get_paths_info(repo_id:, paths:, repo_type: "model", revision: nil, timeout: nil)
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      raise ArgumentError, "paths must be an array" unless paths.is_a?(Array)
      paths.each { |path| DurableHuggingfaceHub::Utils::Validators.validate_filename(path) }
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)
      revision = DurableHuggingfaceHub::Utils::Validators.validate_revision(revision) if revision
      revision ||= "main"

      # For now, implement sequentially. In the future, this could be optimized
      # with concurrent requests or batch API calls if available.
      paths.map do |path|
        begin
          get_hf_file_metadata(
            repo_id: repo_id,
            filename: path,
            repo_type: repo_type,
            revision: revision,
            timeout: timeout
          )
        rescue DurableHuggingfaceHub::EntryNotFoundError
          nil # Return nil for missing files
        end
      end
    end

    # Build a tree structure from the API response.
    #
    # @param items [Array<Hash>] Raw API response items
    # @return [Hash] Organized tree structure
    def build_tree_structure(items)
      tree = {}

      items.each do |item|
        path = item["path"]
        path_parts = path.split("/")

        # Navigate/create nested structure
        current = tree
        path_parts.each_with_index do |part, index|
          is_last = index == path_parts.length - 1

          if is_last
            # This is a file
            current[part] = {
              type: "file",
              size: item["size"],
              oid: item["oid"], # SHA for Git LFS files
              lfs: item["lfs"] # LFS information if applicable
            }.compact
          else
            # This is a directory
            current[part] ||= { type: "directory", children: {} }
            current = current[part][:children]
          end
        end
      end

      tree
    end

    # Create a new repository on the HuggingFace Hub.
    #
    # @param repo_id [String] The ID of the repository to create (e.g., "my-username/my-repo").
    # @param repo_type [String, Symbol] The type of the repository ("model", "dataset", or "space"). Defaults to "model".
    # @param private [Boolean] Whether the repository should be private. Defaults to false.
    # @param organization [String, nil] The organization namespace to create the repository under.
    #   If nil, the repository is created under the authenticated user's namespace.
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [String] The URL of the newly created repository.
    # @raise [ArgumentError] If repo_id or repo_type is invalid.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For API errors (e.g., repository already exists, authentication error).
    def create_repo(repo_id:, repo_type: "model", private: false, organization: nil, timeout: nil)
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)

      # Extract organization from repo_id if not provided
      repo_parts = repo_id.split("/")
      if organization.nil? && repo_parts.length == 2
        # Get current username to check if it's a personal repo
        current_user = whoami
        potential_org = repo_parts[0]
        # Only set organization if it's not the current user
        organization = potential_org unless potential_org == current_user.name
      end
      repo_name = repo_parts.last

      path = "/api/repos/create"
      payload = {
        name: repo_name,
        private: private
      }
      payload[:type] = repo_type if repo_type != "model"
      payload[:organization] = organization if organization

      response = http_client.post(path, body: payload, timeout: timeout)
      body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
      body["url"]
    end

    # Delete a repository from the HuggingFace Hub.
    #
    # @param repo_id [String] The ID of the repository to delete (e.g., "my-username/my-repo").
    # @param repo_type [String, Symbol] The type of the repository ("model", "dataset", or "space"). Defaults to "model".
    # @param token [String, nil] HuggingFace API token. If nil, will attempt to retrieve from environment or token file.
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [Boolean] True if the repository was successfully deleted.
    # @raise [ArgumentError] If repo_id or repo_type is invalid.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the repository does not exist.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors (e.g., authentication error).
    def delete_repo(repo_id:, repo_type: "model", token: nil, timeout: nil)
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)

      path = "/api/#{repo_type}s/#{repo_id}"
      http_client.delete(path)
      true
    end

    # Update the visibility of a repository (public/private).
    #
    # @param repo_id [String] The ID of the repository to update.
    # @param repo_type [String, Symbol] The type of the repository. Defaults to "model".
    # @param private [Boolean] The new visibility status (true for private, false for public).
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [Boolean] True if the visibility was successfully updated.
    # @raise [ArgumentError] If repo_id or repo_type is invalid.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the repository does not exist.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors.
    def update_repo_visibility(repo_id:, repo_type: "model", private:, timeout: nil)
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)

      path = "/api/#{repo_type}s/#{repo_id}/settings"
      payload = { private: private }

      http_client.post(path, body: payload, timeout: timeout)
      true
    end

    # Update various settings for a repository.
    #
    # @param repo_id [String] The ID of the repository to update.
    # @param repo_type [String, Symbol] The type of the repository. Defaults to "model".
    # @param git_lfs_enabled [Boolean, nil] Whether Git LFS should be enabled for the repository.
    # @param protected [Boolean, nil] Whether the repository should be protected.
    # @param unlisted [Boolean, nil] Whether the repository should be unlisted.
    # @param tags [Array<String>, nil] A list of tags to apply to the repository.
    # @param default_branch [String, nil] The new default branch for the repository.
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [Boolean] True if the settings were successfully updated.
    # @raise [ArgumentError] If repo_id or repo_type is invalid.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the repository does not exist.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors.
    def update_repo_settings(
      repo_id:,
      repo_type: "model",
      git_lfs_enabled: nil,
      protected: nil,
      unlisted: nil,
      tags: nil,
      default_branch: nil,
      timeout: nil
    )
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)

      path = "/api/#{repo_type}s/#{repo_id}/settings"
      payload = {}
      payload[:git_lfs_enabled] = git_lfs_enabled unless git_lfs_enabled.nil?
      payload[:protected] = protected unless protected.nil?
      payload[:unlisted] = unlisted unless unlisted.nil?
      payload[:tags] = tags unless tags.nil?
      payload[:default_branch] = default_branch unless default_branch.nil?

      http_client.post(path, body: payload, timeout: timeout)
      true
    end

    # Move or rename a repository.
    #
    # @param from_repo_id [String] The current ID of the repository.
    # @param to_repo_id [String] The new ID for the repository.
    # @param repo_type [String, Symbol] The type of the repository. Defaults to "model".
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [Boolean] True if the repository was successfully moved/renamed.
    # @raise [ArgumentError] If repo_ids or repo_type is invalid.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the source repository does not exist.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors.
    def move_repo(from_repo_id:, to_repo_id:, repo_type: "model", timeout: nil)
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(from_repo_id)
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(to_repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)

      path = "/api/#{repo_type}s/#{from_repo_id}/move"
      payload = { newPath: to_repo_id }

      http_client.post(path, body: payload, timeout: timeout)
      true
    end

    # Duplicate a Space repository.
    #
    # @param from_repo_id [String] The ID of the Space to duplicate.
    # @param to_repo_id [String] The ID for the new duplicated Space.
    # @param private [Boolean, nil] Whether the new Space should be private. Defaults to the original Space's visibility.
    # @param organization [String, nil] The organization namespace to create the new Space under.
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [String] The URL of the newly duplicated Space.
    # @raise [ArgumentError] If repo_ids are invalid.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the source Space does not exist.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors.
    def duplicate_space(from_repo_id:, to_repo_id:, private: nil, organization: nil, timeout: nil)
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(from_repo_id)
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(to_repo_id)

      path = "/api/spaces/#{from_repo_id}/duplicate"
      payload = { newPath: to_repo_id }
      payload[:private] = private unless private.nil?
      payload[:organization] = organization unless organization.nil?

      response = http_client.post(path, body: payload, timeout: timeout)
      body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
      body["url"]
    end

    # Upload a file to a repository on the HuggingFace Hub.
    #
    # @param repo_id [String] The ID of the repository.
    # @param path_or_fileobj [String, Pathname, IO] The path to the file on the local filesystem, or an IO object.
    # @param path_in_repo [String] The path to the file within the repository.
    # @param repo_type [String, Symbol] The type of the repository. Defaults to "model".
    # @param revision [String, nil] The Git revision (branch, tag, or commit SHA) to upload to. Defaults to "main".
    # @param commit_message [String, nil] A custom commit message for the upload.
    # @param commit_description [String, nil] A custom commit description.
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [String] The URL of the uploaded file.
    # @raise [ArgumentError] If parameters are invalid.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the repository does not exist.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors.
    def upload_file(
      repo_id:,
      path_or_fileobj:,
      path_in_repo:,
      repo_type: "model",
      revision: nil,
      commit_message: nil,
      commit_description: nil,
      timeout: nil
    )
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)
      revision = DurableHuggingfaceHub::Utils::Validators.validate_revision(revision) if revision
      revision ||= "main"

      path = "/api/#{repo_type}s/#{repo_id}/upload/#{path_in_repo}"
      params = {
        commit_message: commit_message || "Upload #{path_in_repo}",
        commit_description: commit_description,
        revision: revision
      }.compact

      file_content = if path_or_fileobj.is_a?(String) || path_or_fileobj.is_a?(Pathname)
                       Faraday::Multipart::FilePart.new(path_or_fileobj, "application/octet-stream", Pathname(path_or_fileobj).basename.to_s)
                     else # Assume IO object
                       Faraday::Multipart::FilePart.new(path_or_fileobj, "application/octet-stream")
                     end

      payload = {
        file: file_content
      }

       response = http_client.post(path, params: params, body: payload, timeout: timeout)
       body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
       body["url"]
    end

    # Upload an entire folder to a repository on the HuggingFace Hub.
    #
    # This method iterates through all files in a local folder and uploads them
    # to the specified repository, maintaining the folder structure.
    #
    # @param repo_id [String] The ID of the repository.
    # @param folder_path [String, Pathname] The path to the local folder to upload.
    # @param repo_type [String, Symbol] The type of the repository. Defaults to "model".
    # @param revision [String, nil] The Git revision (branch, tag, or commit SHA) to upload to. Defaults to "main".
    # @param commit_message [String, nil] A custom commit message for the upload.
    # @param commit_description [String, nil] A custom commit description.
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [Array<String>] A list of URLs of the uploaded files.
    # @raise [ArgumentError] If parameters are invalid or folder_path does not exist.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the repository does not exist.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors.
    def upload_folder(
      repo_id:,
      folder_path:,
      repo_type: "model",
      revision: nil,
      commit_message: nil,
      commit_description: nil,
      timeout: nil
    )
      folder_path = Pathname(folder_path)
      raise ArgumentError, "Folder not found: #{folder_path}" unless folder_path.directory?

      uploaded_urls = []
      Dir.glob(File.join(folder_path, "**", "*")).each do |file_path_str|
        file_path = Pathname(file_path_str)
        next if file_path.directory?

        relative_path = file_path.relative_path_from(folder_path).to_s

        uploaded_urls << upload_file(
          repo_id: repo_id,
          path_or_fileobj: file_path,
          path_in_repo: relative_path,
          repo_type: repo_type,
          revision: revision,
          commit_message: commit_message,
          commit_description: commit_description,
          timeout: timeout
        )
      end
      uploaded_urls
    end

    # Delete a file from a repository on the HuggingFace Hub.
    #
    # @param repo_id [String] The ID of the repository.
    # @param path_in_repo [String] The path to the file within the repository to delete.
    # @param repo_type [String, Symbol] The type of the repository. Defaults to "model".
    # @param revision [String, nil] The Git revision (branch, tag, or commit SHA) to delete from. Defaults to "main".
    # @param commit_message [String, nil] A custom commit message for the deletion.
    # @param commit_description [String, nil] A custom commit description.
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [Boolean] True if the file was successfully deleted.
    # @raise [ArgumentError] If parameters are invalid.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the repository does not exist.
    # @raise [DurableHuggingfaceHub::EntryNotFoundError] If the file does not exist in the repository.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors.
    def delete_file(
      repo_id:,
      path_in_repo:,
      repo_type: "model",
      revision: nil,
      commit_message: nil,
      commit_description: nil,
      timeout: nil
    )
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)
      revision = DurableHuggingfaceHub::Utils::Validators.validate_revision(revision) if revision
      revision ||= "main"

      path = "/api/#{repo_type}s/#{repo_id}/upload/#{path_in_repo}"
      params = {
        commit_message: commit_message || "Delete #{path_in_repo}",
        commit_description: commit_description,
        revision: revision
      }.compact

      http_client.delete(path, params: params)
      true
    end

    # Delete an entire folder from a repository on the HuggingFace Hub.
    #
    # This method lists all files within the specified folder in the repository
    # and deletes them one by one.
    #
    # @param repo_id [String] The ID of the repository.
    # @param folder_path_in_repo [String] The path to the folder within the repository to delete.
    # @param repo_type [String, Symbol] The type of the repository. Defaults to "model".
    # @param revision [String, nil] The Git revision (branch, tag, or commit SHA) to delete from. Defaults to "main".
    # @param commit_message [String, nil] A custom commit message for the deletion.
    # @param commit_description [String, nil] A custom commit description.
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [Boolean] True if the folder and its contents were successfully deleted.
    # @raise [ArgumentError] If parameters are invalid.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the repository does not exist.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors.
    def delete_folder(
      repo_id:,
      folder_path_in_repo:,
      repo_type: "model",
      revision: nil,
      commit_message: nil,
      commit_description: nil,
      timeout: nil
    )
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)
      revision = DurableHuggingfaceHub::Utils::Validators.validate_revision(revision) if revision
      revision ||= "main"

      # List all files in the folder
      files_to_delete = list_repo_files(
        repo_id: repo_id,
        repo_type: repo_type,
        revision: revision,
        timeout: timeout
      ).select { |file_path| file_path.start_with?(folder_path_in_repo) }

      # Delete each file
      files_to_delete.each do |file_path|
        delete_file(
          repo_id: repo_id,
          path_in_repo: file_path,
          repo_type: repo_type,
          revision: revision,
          commit_message: commit_message || "Delete #{file_path} from #{folder_path_in_repo}",
          commit_description: commit_description,
          timeout: timeout
        )
      end
      true
    end

    # Check if a file exists in a repository on the HuggingFace Hub.
    #
    # @param repo_id [String] The ID of the repository.
    # @param path_in_repo [String] The path to the file within the repository to check.
    # @param repo_type [String, Symbol] The type of the repository. Defaults to "model".
    # @param revision [String, nil] The Git revision (branch, tag, or commit SHA) to check. Defaults to "main".
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [Boolean] True if the file exists, false otherwise.
    # @raise [ArgumentError] If parameters are invalid.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the repository does not exist.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors.
    def file_exists(repo_id:, path_in_repo:, repo_type: "model", revision: nil, timeout: nil)
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)
      revision = DurableHuggingfaceHub::Utils::Validators.validate_revision(revision) if revision
      revision ||= "main"

      path = "/api/#{repo_type}s/#{repo_id}/resolve/#{revision}/#{path_in_repo}"
       begin
         http_client.head(path, timeout: timeout)
         true
       rescue DurableHuggingfaceHub::RepositoryNotFoundError, DurableHuggingfaceHub::EntryNotFoundError
         false
       end
    end

    # Create a new commit with multiple file operations.
    #
    # @param repo_id [String] The ID of the repository.
    # @param operations [Array<Hash>] An array of file operations (add, delete, update).
    #   Each operation is a hash with at least a `:path` and `:operation` key.
    #   Example: [{ path: "file.txt", operation: "add", content: "new content" }]
    # @param repo_type [String, Symbol] The type of the repository. Defaults to "model".
    # @param revision [String, nil] The Git revision (branch, tag, or commit SHA) to commit to. Defaults to "main".
    # @param commit_message [String, nil] A custom commit message for the upload.
    # @param commit_description [String, nil] A custom commit description.
    # @param parent_commit [String, nil] The SHA of the parent commit.
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [String] The SHA of the newly created commit.
    # @raise [ArgumentError] If parameters are invalid.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the repository does not exist.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors.
    def create_commit(
      repo_id:,
      operations:,
      repo_type: "model",
      revision: nil,
      commit_message: nil,
      commit_description: nil,
      parent_commit: nil,
      timeout: nil
    )
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)
      revision = DurableHuggingfaceHub::Utils::Validators.validate_revision(revision) if revision
      revision ||= "main"

      path = "/api/#{repo_type}s/#{repo_id}/commits/#{revision}"
      payload = {
        operations: operations,
        commit_message: commit_message || "Commit from Ruby client",
        commit_description: commit_description,
        parent_commit: parent_commit
      }.compact

      response = http_client.post(path, body: payload, timeout: timeout)
      body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
      body["commit_id"]
    end

    # Create a new branch in a repository.
    #
    # @param repo_id [String] The ID of the repository.
    # @param branch_name [String] The name of the new branch.
    # @param repo_type [String, Symbol] The type of the repository. Defaults to "model".
    # @param revision [String, nil] The Git revision (branch, tag, or commit SHA) to branch from. Defaults to "main".
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [String] The name of the newly created branch.
    # @raise [ArgumentError] If parameters are invalid.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the repository does not exist.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors (e.g., branch already exists).
    def create_branch(repo_id:, branch_name:, repo_type: "model", revision: nil, timeout: nil)
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)
      revision = DurableHuggingfaceHub::Utils::Validators.validate_revision(revision) if revision
      revision ||= "main"

      path = "/api/#{repo_type}s/#{repo_id}/branches"
       payload = {
         name: branch_name,
         revision: revision
       }.compact

       response = http_client.post(path, body: payload, timeout: timeout)
       body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
       body["name"]
    end

    # Delete a branch from a repository.
    #
    # @param repo_id [String] The ID of the repository.
    # @param branch_name [String] The name of the branch to delete.
    # @param repo_type [String, Symbol] The type of the repository. Defaults to "model".
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [Boolean] True if the branch was successfully deleted.
    # @raise [ArgumentError] If parameters are invalid.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the repository does not exist.
    # @raise [DurableHuggingfaceHub::RevisionNotFoundError] If the branch does not exist.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors.
    def delete_branch(repo_id:, branch_name:, repo_type: "model", timeout: nil)
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)

      path = "/api/#{repo_type}s/#{repo_id}/branches/#{branch_name}"
      http_client.delete(path)
      true
    end

    # Create a new tag in a repository.
    #
    # @param repo_id [String] The ID of the repository.
    # @param tag_name [String] The name of the new tag.
    # @param repo_type [String, Symbol] The type of the repository. Defaults to "model".
    # @param revision [String, nil] The Git revision (branch, tag, or commit SHA) to tag from. Defaults to "main".
    # @param message [String, nil] An optional message for the tag.
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [String] The name of the newly created tag.
    # @raise [ArgumentError] If parameters are invalid.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the repository does not exist.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors (e.g., tag already exists).
    def create_tag(repo_id:, tag_name:, repo_type: "model", revision: nil, message: nil, timeout: nil)
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)
      revision = DurableHuggingfaceHub::Utils::Validators.validate_revision(revision) if revision
      revision ||= "main"

      path = "/api/#{repo_type}s/#{repo_id}/tags"
       payload = {
         name: tag_name,
         revision: revision,
         message: message
       }.compact

       response = http_client.post(path, body: payload, timeout: timeout)
       body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
       body["name"]
    end

    # Delete a tag from a repository.
    #
    # @param repo_id [String] The ID of the repository.
    # @param tag_name [String] The name of the tag to delete.
    # @param repo_type [String, Symbol] The type of the repository. Defaults to "model".
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [Boolean] True if the tag was successfully deleted.
    # @raise [ArgumentError] If parameters are invalid.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the repository does not exist.
    # @raise [DurableHuggingfaceHub::RevisionNotFoundError] If the tag does not exist.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors.
    def delete_tag(repo_id:, tag_name:, repo_type: "model", timeout: nil)
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)

      path = "/api/#{repo_type}s/#{repo_id}/tags/#{tag_name}"
      http_client.delete(path)
      true
    end

    # List branches and tags (refs) for a repository.
    #
    # @param repo_id [String] The ID of the repository.
    # @param repo_type [String, Symbol] The type of the repository. Defaults to "model".
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [Hash] A hash containing arrays of "branches" and "tags".
    # @raise [ArgumentError] If repo_id or repo_type is invalid.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the repository does not exist.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors.
    def list_repo_refs(repo_id:, repo_type: "model", timeout: nil)
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)

       path = "/api/#{repo_type}s/#{repo_id}/refs"
       response = http_client.get(path, timeout: timeout)

       body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
       branches = body["branches"].map { |branch_data| DurableHuggingfaceHub::Types::GitRefInfo.from_hash(branch_data) }
       tags = body["tags"].map { |tag_data| DurableHuggingfaceHub::Types::GitRefInfo.from_hash(tag_data) }

      { branches: branches, tags: tags }
    end

    # List commit history for a repository.
    #
    # @param repo_id [String] The ID of the repository.
    # @param repo_type [String, Symbol] The type of the repository. Defaults to "model".
    # @param revision [String, nil] The Git revision (branch, tag, or commit SHA) to list commits from. Defaults to "main".
    # @param limit [Integer, nil] The maximum number of commits to return.
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [Array<DurableHuggingfaceHub::Types::CommitInfo>] A list of commit information objects.
    # @raise [ArgumentError] If repo_id or repo_type is invalid.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the repository does not exist.
    # @raise [DurableHuggingfaceHub::RevisionNotFoundError] If the revision does not exist.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors.
    def list_repo_commits(repo_id:, repo_type: "model", revision: nil, limit: nil, timeout: nil)
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)
      revision = DurableHuggingfaceHub::Utils::Validators.validate_revision(revision) if revision
      revision ||= "main"

      path = "/api/#{repo_type}s/#{repo_id}/commits"
      params = {
        revision: revision,
        limit: limit
      }.compact

       response = http_client.get(path, params: params, timeout: timeout)
       body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
       body.map do |commit_data|
        # Flatten the nested commit structure
        commit = commit_data["commit"]
        author = commit["author"]
        {
          oid: commit["id"],
          title: commit["message"]&.split("\n")&.first, # First line as title
          message: commit["message"],
          date: author ? Time.parse(author["date"]) : nil,
          authors: author ? [author["name"]] : nil
        }.compact
      end.map { |data| DurableHuggingfaceHub::Types::CommitInfo.from_hash(data) }
    end

    # List Git LFS files in a repository.
    #
    # @param repo_id [String] The ID of the repository.
    # @param repo_type [String, Symbol] The type of the repository. Defaults to "model".
    # @param revision [String, nil] The Git revision (branch, tag, or commit SHA) to list LFS files from. Defaults to "main".
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [Array<Hash>] A list of LFS file information hashes.
    # @raise [ArgumentError] If repo_id or repo_type is invalid.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the repository does not exist.
    # @raise [DurableHuggingfaceHub::RevisionNotFoundError] If the revision does not exist.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors.
    def list_lfs_files(repo_id:, repo_type: "model", revision: nil, timeout: nil)
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)
      revision = DurableHuggingfaceHub::Utils::Validators.validate_revision(revision) if revision
      revision ||= "main"

      path = "/api/#{repo_type}s/#{repo_id}/lfs/objects"
      params = { revision: revision }.compact

       response = http_client.get(path, params: params, timeout: timeout)
       response.body.is_a?(String) ? JSON.parse(response.body) : response.body
    end

    # Permanently delete LFS files from a repository.
    #
    # @param repo_id [String] The ID of the repository.
    # @param lfs_oids [Array<String>] A list of LFS object IDs (OIDs) to delete.
    # @param repo_type [String, Symbol] The type of the repository. Defaults to "model".
    # @param timeout [Numeric, nil] Request timeout in seconds.
    # @return [Boolean] True if the LFS files were successfully deleted.
    # @raise [ArgumentError] If parameters are invalid.
    # @raise [DurableHuggingfaceHub::RepositoryNotFoundError] If the repository does not exist.
    # @raise [DurableHuggingfaceHub::HfHubHTTPError] For other API errors.
    def permanently_delete_lfs_files(repo_id:, lfs_oids:, repo_type: "model", timeout: nil)
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)

      path = "/api/#{repo_type}s/#{repo_id}/lfs/delete"
      payload = { oids: lfs_oids }

      http_client.post(path, body: payload, timeout: timeout)
      true
    end

    private

    # Build query parameters for list endpoints
    #
    # @param filter [String, Hash, nil] Filter criteria
    # @param author [String, nil] Author filter
    # @param search [String, nil] Search query
    # @param sort [String, Symbol, nil] Sort criterion
    # @param direction [Integer, nil] Sort direction
    # @param limit [Integer, nil] Result limit
    # @param full [Boolean] Fetch full information
    #
    # @return [Hash] Query parameters
    def build_list_params(filter:, author:, search:, sort:, direction:, limit:, full:)
      params = {}

      # Handle filter parameter
      if filter
        case filter
        when String
          # Single tag or search term
          params[:filter] = filter
        when Hash
          # Structured filters - convert to Hub API format
          filter.each do |key, value|
            params[key.to_s] = value
          end
        end
      end

      params[:author] = author if author
      params[:search] = search if search
      params[:sort] = sort.to_s if sort
      params[:direction] = direction if direction
      params[:limit] = limit if limit
      params[:full] = full if full

      params
    end
  end
end
