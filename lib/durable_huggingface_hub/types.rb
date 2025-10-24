# frozen_string_literal: true

require "dry-types"
require "dry-struct"

module DurableHuggingfaceHub
  # Type definitions and custom types for the HuggingFace Hub client.
  #
  # This module sets up the type system using dry-types and defines
  # custom types for domain-specific validation and coercion.
  #
  # @example Using custom types
  #   Types::RepoId["organization/model-name"]
  #   Types::RepoType["model"]
  #   Types::Revision["main"]
  module Types
    include Dry.Types()

    # Repository ID type with validation.
    #
    # Valid format: "organization/repository-name" or "username/repository-name"
    # May also be just "repository-name" for models in the user's namespace.
    #
    # @example
    #   Types::RepoId["bert-base-uncased"]
    #   Types::RepoId["huggingface/transformers"]
    RepoId = String.constrained(min_size: 1)

    # Repository type enumeration.
    #
    # Valid values: "model", "dataset", "space"
    #
    # @example
    #   Types::RepoType["model"]
    #   Types::RepoType["dataset"]
    RepoType = String.enum("model", "dataset", "space")

    # Revision type (branch, tag, or commit SHA).
    #
    # Can be a branch name (e.g., "main"), tag (e.g., "v1.0.0"),
    # or Git commit SHA (40 hexadecimal characters).
    #
    # @example
    #   Types::Revision["main"]
    #   Types::Revision["v1.0.0"]
    #   Types::Revision["a1b2c3d4e5f6..."]
    Revision = String.constrained(min_size: 1)

    # Strict boolean type.
    StrictBool = Strict::Bool

    # Optional string type.
    OptionalString = String.optional

    # Optional integer type.
    OptionalInteger = Integer.optional

    # Optional boolean type.
    OptionalBool = Bool.optional

    # Array of strings type.
    StringArray = Array.of(String)

    # Optional array of strings type.
    OptionalStringArray = Array.of(String).optional

    # Hash with string keys type.
    StringHash = Hash.map(String, Any)

    # Optional hash type.
    OptionalHash = Hash.optional

    # Timestamp type (Time, DateTime, or ISO 8601 string).
    Timestamp = Time | DateTime | String

    # Optional timestamp type.
    OptionalTimestamp = Timestamp.optional

    # File siblings type (array of hashes representing files in a repository).
    FileSiblings = Array.of(Hash)

    # Optional file siblings type.
    OptionalFileSiblings = FileSiblings.optional

    # Gated access type (true, false, "auto", "manual").
    GatedType = Bool | String.enum("auto", "manual")

    # Optional gated type.
    OptionalGated = GatedType.optional

    # URL type for web addresses.
    #
    # Accepts any string that looks like a URL.
    #
    # @example
    #   Types::URL["https://example.com"]
    #   Types::URL["http://example.com/path"]
    URL = String.constrained(format: URI::DEFAULT_PARSER.make_regexp)

    # Optional URL type.
    OptionalURL = URL.optional

    # Pathname type for file system paths.
    #
    # Accepts strings, Pathname objects, or anything that responds to #to_path or #to_s.
    #
    # @example
    #   Types::PathnameType["/path/to/file"]
    #   Types::PathnameType[Pathname.new("/path/to/file")]
    PathnameType = Any.constructor do |value|
      case value
      when Pathname
        value
      when String
        Pathname.new(value)
      else
        Pathname.new(value.to_s)
      end
    end

    # Optional Pathname type.
    OptionalPathnameType = PathnameType.optional
  end

  # Autoload type structures
  module Types
    autoload :ModelInfo, "durable_huggingface_hub/types/model_info"
    autoload :DatasetInfo, "durable_huggingface_hub/types/dataset_info"
    autoload :SpaceInfo, "durable_huggingface_hub/types/space_info"
    autoload :CommitInfo, "durable_huggingface_hub/types/commit_info"
    autoload :GitRefInfo, "durable_huggingface_hub/types/commit_info"
    autoload :User, "durable_huggingface_hub/types/user"
    autoload :Organization, "durable_huggingface_hub/types/user"
    autoload :CachedFileInfo, "durable_huggingface_hub/types/cache_info"
    autoload :CachedRevisionInfo, "durable_huggingface_hub/types/cache_info"
    autoload :CachedRepoInfo, "durable_huggingface_hub/types/cache_info"
    autoload :HFCacheInfo, "durable_huggingface_hub/types/cache_info"
  end

  # Base class for data structures using dry-struct.
  #
  # Provides immutable, type-checked data structures with automatic
  # attribute validation and coercion.
  #
  # @example Defining a data structure
  #   class MyData < DurableHuggingfaceHub::Struct
  #     attribute :name, Types::String
  #     attribute :count, Types::Integer
  #     attribute :optional, Types::OptionalString
  #   end
  class Struct < Dry::Struct
    # Use type schema for strict attribute validation
    schema schema.strict

    # Transform attribute keys from camelCase strings to snake_case symbols
    transform_keys do |key|
      # Convert camelCase to snake_case, then to symbol
      key.to_s.gsub(/([a-z])([A-Z])/, '\1_\2').downcase.to_sym
    end

    # Base class for data structures that can be loaded from JSON/Hash.
    #
    # Provides convenient methods for creating instances from API responses.
    module Loadable
      # Creates an instance from a hash (typically from JSON parsing).
      #
      # @param data [Hash] Data hash
      # @return [Struct] New instance
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # Creates an instance from a hash.
        #
        # @param data [Hash] Data hash with string or symbol keys
        # @return [self] New instance of the struct
        def from_hash(data)
          new(data)
        end

        # Alias for from_hash.
        #
        # @param data [Hash] Data hash
        # @return [self] New instance
        alias from_json from_hash
      end

      # Converts the struct to a hash.
      #
      # @return [Hash] Hash representation
      def to_h
        attributes.to_h
      end

      # Converts the struct to JSON.
      #
      # @return [String] JSON representation
      def to_json(*args)
        require "json"
        to_h.to_json(*args)
      end
    end
  end
end
