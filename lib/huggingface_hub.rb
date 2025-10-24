# frozen_string_literal: true

# DurableHuggingfaceHub is a Ruby client library for the HuggingFace Hub.
#
# This library provides a pure Ruby implementation of the HuggingFace Hub client,
# enabling users to download models, datasets, and other files from the HuggingFace Hub,
# manage repositories, and interact with HuggingFace's inference APIs.
#
# @example Basic usage
#   require "huggingface_hub"
#
#   # Configure the library
#   DurableHuggingfaceHub.configure do |config|
#     config.token = "hf_your_token_here"
#   end
#
#   # Use the library features
#   # (Additional features will be added in subsequent phases)
#
# @see https://huggingface.co HuggingFace Hub
# @see https://github.com/durableprogramming/huggingface-hub-ruby Project repository
module DurableHuggingfaceHub
  # Autoload core modules for efficient memory usage
  autoload :Constants, "durable_huggingface_hub/constants"
  autoload :Configuration, "durable_huggingface_hub/configuration"
  autoload :VERSION, "durable_huggingface_hub/version"
  autoload :Types, "durable_huggingface_hub/types"
  autoload :FileDownload, "durable_huggingface_hub/file_download"
  autoload :HfApi, "durable_huggingface_hub/hf_api"
  autoload :RepoCard, "durable_huggingface_hub/repo_card"
  autoload :ModelCard, "durable_huggingface_hub/repo_card"
  autoload :DatasetCard, "durable_huggingface_hub/repo_card"
  autoload :SpaceCard, "durable_huggingface_hub/repo_card"
  autoload :Cache, "durable_huggingface_hub/cache"

  # Utils module with HTTP, retry, and header utilities
  module Utils
    autoload :Headers, "durable_huggingface_hub/utils/headers"
    autoload :Retry, "durable_huggingface_hub/utils/retry"
    autoload :HttpClient, "durable_huggingface_hub/utils/http"
    autoload :Auth, "durable_huggingface_hub/utils/auth"
    autoload :Validators, "durable_huggingface_hub/utils/validators"
    autoload :Paths, "durable_huggingface_hub/utils/paths"
    autoload :Progress, "durable_huggingface_hub/utils/progress"
  end

  # Load errors immediately since they may be needed for any operation
  require_relative "durable_huggingface_hub/errors"

  # Load authentication module
  require_relative "durable_huggingface_hub/authentication"

  class << self
    # Returns the library version.
    #
    # @return [String] The current version string
    def version
      VERSION
    end

    # Returns the global configuration instance.
    #
    # @return [Configuration] The configuration instance
    def configuration
      Configuration.instance
    end

    # Configures the library with a block.
    #
    # @yield [config] The configuration instance
    # @example
    #   DurableHuggingfaceHub.configure do |config|
    #     config.token = "hf_..."
    #   end
    def configure
      yield configuration if block_given?
    end

    # Delegates to Authentication.login
    # @see Authentication.login
    def login(token: nil, add_to_git_credential: false)
      Authentication.login(token: token, add_to_git_credential: add_to_git_credential)
    end

    # Delegates to Authentication.logout
    # @see Authentication.logout
    def logout
      Authentication.logout
    end

    # Delegates to Authentication.whoami
    # @see Authentication.whoami
    def whoami(token: nil)
      Authentication.whoami(token: token)
    end

    # Delegates to Authentication.logged_in?
    # @see Authentication.logged_in?
    def logged_in?
      Authentication.logged_in?
    end

    # Delegates to FileDownload.hf_hub_download
    # @see FileDownload.hf_hub_download
    def hf_hub_download(**kwargs)
      FileDownload.hf_hub_download(**kwargs)
    end

    # Delegates to FileDownload.snapshot_download
    # @see FileDownload.snapshot_download
    def snapshot_download(**kwargs)
      FileDownload.snapshot_download(**kwargs)
    end

    # Delegates to Cache.scan_cache_dir
    # @see Cache.scan_cache_dir
    def scan_cache_dir(**kwargs)
      Cache.scan_cache_dir(**kwargs)
    end

    # Delegates to Cache.cached_assets_path
    # @see Cache.cached_assets_path
    def cached_assets_path(**kwargs)
      Cache.cached_assets_path(**kwargs)
    end

    # Delegates to HfApi.repo_info
    # @see HfApi.repo_info
    def repo_info(repo_id, repo_type: "model", revision: nil, timeout: nil)
      HfApi.new.repo_info(repo_id, repo_type: repo_type, revision: revision, timeout: timeout)
    end

    # Delegates to HfApi.model_info
    # @see HfApi.model_info
    def model_info(repo_id, revision: nil, timeout: nil)
      HfApi.new.model_info(repo_id, revision: revision, timeout: timeout)
    end

    # Delegates to HfApi.dataset_info
    # @see HfApi.dataset_info
    def dataset_info(repo_id, revision: nil, timeout: nil)
      HfApi.new.dataset_info(repo_id, revision: revision, timeout: timeout)
    end

    # Delegates to HfApi.space_info
    # @see HfApi.space_info
    def space_info(repo_id, revision: nil, timeout: nil)
      HfApi.new.space_info(repo_id, revision: revision, timeout: timeout)
    end

    # Delegates to HfApi.list_models
    # @see HfApi.list_models
    def list_models(filter: nil, author: nil, search: nil, sort: nil,
                    direction: nil, limit: nil, full: false, timeout: nil)
      HfApi.new.list_models(filter: filter, author: author, search: search, sort: sort,
                            direction: direction, limit: limit, full: full, timeout: timeout)
    end

    # Delegates to HfApi.list_datasets
    # @see HfApi.list_datasets
    def list_datasets(filter: nil, author: nil, search: nil, sort: nil,
                      direction: nil, limit: nil, full: false, timeout: nil)
      HfApi.new.list_datasets(filter: filter, author: author, search: search, sort: sort,
                              direction: direction, limit: limit, full: full, timeout: timeout)
    end

    # Delegates to HfApi.list_spaces
    # @see HfApi.list_spaces
    def list_spaces(filter: nil, author: nil, search: nil, sort: nil,
                    direction: nil, limit: nil, full: false, timeout: nil)
      HfApi.new.list_spaces(filter: filter, author: author, search: search, sort: sort,
                            direction: direction, limit: limit, full: full, timeout: timeout)
    end

    # Delegates to HfApi.repo_exists
    # @see HfApi.repo_exists
    def repo_exists(repo_id, repo_type: "model", timeout: nil)
      HfApi.new.repo_exists(repo_id, repo_type: repo_type, timeout: timeout)
    end

    # Delegates to HfApi.whoami
    # @see HfApi.whoami
    # @raise [LocalTokenNotFoundError] If no token is provided or found
    def whoami(token: nil)
      # Ensure a token is available before making API call
      token = Utils::Auth.get_token!(token: token)
      HfApi.new(token: token).whoami
    end

    # Delegates to FileDownload.try_to_load_from_cache
    # @see FileDownload.try_to_load_from_cache
    def try_to_load_from_cache(**kwargs)
      FileDownload.try_to_load_from_cache(**kwargs)
    end

    # Delegates to FileDownload.hf_hub_url
    # @see FileDownload.hf_hub_url
    def hf_hub_url(**kwargs)
      FileDownload.hf_hub_url(**kwargs)
    end
  end
end

# Require version to make it available immediately
require_relative "durable_huggingface_hub/version"
