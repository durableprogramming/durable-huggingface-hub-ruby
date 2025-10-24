# frozen_string_literal: true

require_relative "../types"

module DurableHuggingfaceHub
  module Types
    # Information about a model repository on HuggingFace Hub.
    #
    # This structure represents metadata about a model, including its ID,
    # tags, files, statistics, and configuration.
    #
    # @example Creating a ModelInfo from API response
    #   model_info = ModelInfo.from_hash({
    #     "id" => "bert-base-uncased",
    #     "sha" => "a1b2c3d4...",
    #     "tags" => ["transformers", "pytorch"],
    #     "downloads" => 1000000,
    #     "likes" => 500
    #   })
    #
    # @example Accessing model information
    #   model_info.id          # => "bert-base-uncased"
    #   model_info.tags        # => ["transformers", "pytorch"]
    #   model_info.downloads   # => 1000000
    class ModelInfo < DurableHuggingfaceHub::Struct
      include Loadable

      # @!attribute [r] id
      #   @return [String] Model repository ID (e.g., "bert-base-uncased")
      attribute :id, Types::RepoId

      # @!attribute [r] sha
      #   @return [String, nil] Git commit SHA of the current revision
      attribute :sha, Types::OptionalString.default(nil)

      # @!attribute [r] last_modified
      #   @return [Time, nil] Timestamp of last modification
      attribute :last_modified, Types::OptionalTimestamp.default(nil)

      # @!attribute [r] tags
      #   @return [Array<String>] Tags associated with the model
      attribute :tags, Types::StringArray.default([].freeze)

      # @!attribute [r] pipeline_tag
      #   @return [String, nil] Primary pipeline/task tag (e.g., "text-classification")
      attribute :pipeline_tag, Types::OptionalString.default(nil)

      # @!attribute [r] siblings
      #   @return [Array<Hash>, nil] List of files in the repository
      attribute :siblings, Types::OptionalFileSiblings.default(nil)

      # @!attribute [r] private
      #   @return [Boolean, nil] Whether the repository is private
      attribute :private, Types::OptionalBool.default(nil)

       # @!attribute [r] gated
       #   @return [Boolean, String, nil] Gated access status (false, "auto", "manual")
       attribute :gated, Types::OptionalGated.default(nil)

      # @!attribute [r] disabled
      #   @return [Boolean, nil] Whether the repository is disabled
      attribute :disabled, Types::OptionalBool.default(nil)

      # @!attribute [r] downloads
      #   @return [Integer, nil] Total number of downloads
      attribute :downloads, Types::OptionalInteger.default(nil)

      # @!attribute [r] likes
      #   @return [Integer, nil] Number of likes/stars
      attribute :likes, Types::OptionalInteger.default(nil)

      # @!attribute [r] library_name
      #   @return [String, nil] Primary library (e.g., "transformers", "diffusers")
      attribute :library_name, Types::OptionalString.default(nil)

      # @!attribute [r] config
      #   @return [Hash, nil] Model configuration data
      attribute :config, Types::OptionalHash.default(nil)

      # @!attribute [r] author
      #   @return [String, nil] Author/organization name
      attribute :author, Types::OptionalString.default(nil)

      # @!attribute [r] created_at
      #   @return [Time, nil] Repository creation timestamp
      attribute :created_at, Types::OptionalTimestamp.default(nil)

      # @!attribute [r] card_data
      #   @return [Hash, nil] Model card metadata
      attribute :card_data, Types::OptionalHash.default(nil)

      # Returns the list of file names in the repository.
      #
      # @return [Array<String>] File names
      def file_names
        return [] if siblings.nil?

        siblings.map { |s| s[:rfilename] || s["rfilename"] }.compact
      end

      # Checks if the model has a specific tag.
      #
      # @param tag [String] Tag to check for
      # @return [Boolean] True if the tag is present
      def has_tag?(tag)
        tags.include?(tag)
      end

      # Checks if the repository is public.
      #
      # @return [Boolean] True if public (not private)
      def public?
        !private
      end

      # Checks if the repository is gated.
      #
      # @return [Boolean] True if gated
      def gated?
        case gated
        when true, "auto", "manual"
          true
        else
          false
        end
      end

      # Checks if the repository is disabled.
      #
      # @return [Boolean] True if disabled
      def disabled?
        disabled == true
      end

      # Returns a short description of the model.
      #
      # @return [String] Description string
      def to_s
        parts = [id]
        parts << "(#{pipeline_tag})" if pipeline_tag
        parts << "[#{library_name}]" if library_name
        parts.join(" ")
      end

      # Returns a detailed inspection string.
      #
      # @return [String] Inspection string
      def inspect
        "#<#{self.class.name} id=#{id.inspect} sha=#{sha&.[](0, 7).inspect} " \
          "tags=#{tags.size} files=#{siblings&.size || 0}>"
      end
    end
  end
end
