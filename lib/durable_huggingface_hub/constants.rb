# frozen_string_literal: true

module DurableHuggingfaceHub
  # Constants used throughout the HuggingFace Hub client library.
  #
  # This module contains URL endpoints, file patterns, timeout values, size limits,
  # and other configuration constants required for interacting with the HuggingFace Hub API.
  module Constants
     # Default HuggingFace Hub endpoint URL
     ENDPOINT = "https://huggingface.co"

     # HuggingFace Hub home URL
     HUGGINGFACE_CO_URL_HOME = "https://huggingface.co/"

     # Template for constructing HuggingFace Hub URLs
     HUGGINGFACE_CO_URL_TEMPLATE = "https://huggingface.co/{repo_id}/resolve/{revision}/{filename}"

     # Default inference endpoint URL
     INFERENCE_ENDPOINT = "https://api-inference.huggingface.co"

     # Inference endpoints API URL
     INFERENCE_ENDPOINTS_ENDPOINT = "https://api.endpoints.huggingface.cloud/v2"

     # Inference catalog endpoint URL
     INFERENCE_CATALOG_ENDPOINT = "https://endpoints.huggingface.co/api/catalog"

     # Inference proxy template
     INFERENCE_PROXY_TEMPLATE = "https://router.huggingface.co/{provider}"

     # Inference endpoint image keys
     INFERENCE_ENDPOINT_IMAGE_KEYS = [
       "custom",
       "huggingface",
       "huggingfaceNeuron",
       "llamacpp",
       "tei",
       "tgi",
       "tgiNeuron"
     ].freeze

    # Separator used in repository IDs (e.g., organization/model-name)
    REPO_ID_SEPARATOR = "/"

    # Default revision/branch name for repositories
    DEFAULT_REVISION = "main"

    # Regular expression pattern for validating commit OIDs (Git SHA-1 hashes)
    # Matches 40 hexadecimal characters
    REGEX_COMMIT_OID = /\A[0-9a-f]{40}\z/i

     # File naming conventions for PyTorch models
     PYTORCH_WEIGHTS_NAME = "pytorch_model.bin"
     PYTORCH_WEIGHTS_INDEX_NAME = "pytorch_model.bin.index.json"
     PYTORCH_WEIGHTS_FILE_PATTERN = "pytorch_model{suffix}.bin"

     # TensorFlow model file names
     TF2_WEIGHTS_NAME = "tf_model.h5"
     TF_WEIGHTS_NAME = "model.ckpt"
     TF2_WEIGHTS_FILE_PATTERN = "tf_model{suffix}.h5"

     # Flax model file names
     FLAX_WEIGHTS_NAME = "flax_model.msgpack"

     # SafeTensors file patterns (preferred format for model weights)
     SAFETENSORS_WEIGHTS_FILE_PATTERN = "model*.safetensors"
     SAFETENSORS_WEIGHTS_FILE_PATTERN_SUFFIX = "model{suffix}.safetensors"
     SAFETENSORS_SINGLE_FILE = "model.safetensors"
     SAFETENSORS_INDEX_FILE = "model.safetensors.index.json"
     SAFETENSORS_MAX_HEADER_LENGTH = 25_000_000

     # Configuration and metadata file names
     CONFIG_NAME = "config.json"
     REPOCARD_NAME = "README.md"

    # Timeout configuration (in seconds)

    # Timeout for ETag validation requests
    DEFAULT_ETAG_TIMEOUT = 10

    # Timeout for file download operations
    DEFAULT_DOWNLOAD_TIMEOUT = 600  # 10 minutes

    # Timeout for general API requests
    DEFAULT_REQUEST_TIMEOUT = 10

     # Download and file size configuration

     # Size of chunks for streaming downloads (10 MB)
     DOWNLOAD_CHUNK_SIZE = 10 * 1024 * 1024

     # Maximum size for HTTP downloads before requiring streaming (50 GB)
     MAX_HTTP_DOWNLOAD_SIZE = 50 * 1024 * 1024 * 1024

     # LFS (Large File Storage) threshold - files larger than this use LFS (10 MB)
     LFS_THRESHOLD = 10 * 1024 * 1024

     # File lock logging interval (in seconds)
     FILELOCK_LOG_EVERY_SECONDS = 10

     # Repository type constants
     REPO_TYPE_MODEL = "model"
     REPO_TYPE_DATASET = "dataset"
     REPO_TYPE_SPACE = "space"

     # Valid repository types (including nil for backward compatibility)
     REPO_TYPES = [nil, REPO_TYPE_MODEL, REPO_TYPE_DATASET, REPO_TYPE_SPACE].freeze

     # Repository ID serialization separator (used for serialization of repo ids elsewhere)
     REPO_ID_SERIALIZATION_SEPARATOR = "--"

     # Space SDK types
     SPACES_SDK_TYPES = ["gradio", "streamlit", "docker", "static"].freeze

     # Repository type URL prefixes
     REPO_TYPES_URL_PREFIXES = {
       REPO_TYPE_DATASET => "datasets/",
       REPO_TYPE_SPACE => "spaces/"
     }.freeze

     # Repository type mappings
     REPO_TYPES_MAPPING = {
       "datasets" => REPO_TYPE_DATASET,
       "spaces" => REPO_TYPE_SPACE,
       "models" => REPO_TYPE_MODEL
     }.freeze

    # Cache directory structure
    HF_CACHE_SUBDIR = "hub"
    MODELS_CACHE_SUBDIR = "models"

     # HTTP header names
     HEADER_X_REPO_COMMIT = "X-Repo-Commit"
     HEADER_X_LINKED_SIZE = "X-Linked-Size"
     HEADER_X_LINKED_ETAG = "X-Linked-Etag"
     HEADER_X_BILL_TO = "X-HF-Bill-To"
     HEADER_X_XET_ENDPOINT = "X-Xet-Cas-Url"
     HEADER_X_XET_ACCESS_TOKEN = "X-Xet-Access-Token"
     HEADER_X_XET_EXPIRATION = "X-Xet-Token-Expiration"
     HEADER_X_XET_HASH = "X-Xet-Hash"
     HEADER_X_XET_REFRESH_ROUTE = "X-Xet-Refresh-Route"

    # User agent string for API requests
    USER_AGENT = "huggingface_hub/#{VERSION}; ruby/#{RUBY_VERSION}"
  end
end
