# frozen_string_literal: true

require_relative "../types"

module DurableHuggingfaceHub
  module Types
    # Information about a dataset repository on HuggingFace Hub.
    #
    # This structure represents metadata about a dataset, including its ID,
    # tags, files, statistics, and configuration.
    #
    # @example Creating a DatasetInfo from API response
    #   dataset_info = DatasetInfo.from_hash({
    #     "id" => "squad",
    #     "sha" => "a1b2c3d4...",
    #     "tags" => ["question-answering", "en"],
    #     "downloads" => 500000
    #   })
    #
    # @example Accessing dataset information
    #   dataset_info.id          # => "squad"
    #   dataset_info.tags        # => ["question-answering", "en"]
    #   dataset_info.downloads   # => 500000
    class DatasetInfo < DurableHuggingfaceHub::Struct
      include Loadable

      # @!attribute [r] id
      #   @return [String] Dataset repository ID
      attribute :id, Types::RepoId

      # @!attribute [r] sha
      #   @return [String, nil] Git commit SHA of the current revision
      attribute :sha, Types::OptionalString.default(nil)

      # @!attribute [r] last_modified
      #   @return [Time, nil] Timestamp of last modification
      attribute :last_modified, Types::OptionalTimestamp.default(nil)

      # @!attribute [r] tags
      #   @return [Array<String>] Tags associated with the dataset
      attribute :tags, Types::StringArray.default([].freeze)

      # @!attribute [r] siblings
      #   @return [Array<Hash>, nil] List of files in the repository
      attribute :siblings, Types::OptionalFileSiblings.default(nil)

      # @!attribute [r] private
      #   @return [Boolean, nil] Whether the repository is private
      attribute :private, Types::OptionalBool.default(nil)

       # @!attribute [r] gated
       #   @return [Boolean, String, nil] Gated access status
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

      # @!attribute [r] author
      #   @return [String, nil] Author/organization name
      attribute :author, Types::OptionalString.default(nil)

      # @!attribute [r] created_at
      #   @return [Time, nil] Repository creation timestamp
      attribute :created_at, Types::OptionalTimestamp.default(nil)

      # @!attribute [r] card_data
      #   @return [Hash, nil] Dataset card metadata
      attribute :card_data, Types::OptionalHash.default(nil)

      # @!attribute [r] description
      #   @return [String, nil] Dataset description
      attribute :description, Types::OptionalString.default(nil)

       # @!attribute [r] citation
       #   @return [String, nil] Citation information
       attribute :citation, Types::OptionalString.default(nil)

       # @!attribute [r] downloads_all_time
       #   @return [Integer, nil] Total number of downloads all time
       attribute :downloads_all_time, Types::OptionalInteger.default(nil)

       # @!attribute [r] paperswithcode_id
       #   @return [String, nil] PapersWithCode identifier
       attribute :paperswithcode_id, Types::OptionalString.default(nil)

       # @!attribute [r] trending_score
       #   @return [Integer, nil] Trending score
       attribute :trending_score, Types::OptionalInteger.default(nil)

       # Transform API response to filter out unknown keys
       def self.from_hash(data)
         transformed = data.dup

         # Filter out unknown keys to avoid dry-struct errors
         known_keys = [:id, :sha, :last_modified, :tags, :siblings, :private, :gated,
                       :disabled, :downloads, :likes, :author, :created_at, :card_data,
                       :description, :citation, :downloads_all_time, :paperswithcode_id,
                       :trending_score,
                       "id", "sha", "last_modified", "tags", "siblings", "private", "gated",
                       "disabled", "downloads", "likes", "author", "created_at", "card_data",
                       "description", "citation", "downloads_all_time", "paperswithcode_id",
                       "trending_score"]
         transformed = transformed.select { |k, _| known_keys.include?(k) }

         new(transformed)
       end

       # Returns the list of file names in the repository.
      #
      # @return [Array<String>] File names
      def file_names
        return [] if siblings.nil?

        siblings.map { |s| s[:rfilename] || s["rfilename"] }.compact
      end

      # Checks if the dataset has a specific tag.
      #
      # @param tag [String] Tag to check for
      # @return [Boolean] True if the tag is present
      def has_tag?(tag)
        tags.include?(tag)
      end

      # Checks if the repository is public.
      #
      # @return [Boolean] True if public
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

      # Returns a short description of the dataset.
      #
      # @return [String] Description string
      def to_s
        id
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
