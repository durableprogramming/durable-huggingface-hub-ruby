# frozen_string_literal: true

require_relative "../types"

module DurableHuggingfaceHub
  module Types
    # Information about a Space repository on HuggingFace Hub.
    #
    # Spaces are interactive ML demos and applications hosted on HuggingFace Hub.
    #
    # @example Creating a SpaceInfo from API response
    #   space_info = SpaceInfo.from_hash({
    #     "id" => "gradio/hello-world",
    #     "sdk" => "gradio",
    #     "tags" => ["gradio", "demo"],
    #     "likes" => 100
    #   })
    #
    # @example Accessing space information
    #   space_info.id      # => "gradio/hello-world"
    #   space_info.sdk     # => "gradio"
    #   space_info.runtime # => {"stage" => "RUNNING"}
    class SpaceInfo < DurableHuggingfaceHub::Struct
      include Loadable

      # @!attribute [r] id
      #   @return [String] Space repository ID
      attribute :id, Types::RepoId

      # @!attribute [r] sha
      #   @return [String, nil] Git commit SHA of the current revision
      attribute :sha, Types::OptionalString.default(nil)

      # @!attribute [r] last_modified
      #   @return [Time, nil] Timestamp of last modification
      attribute :last_modified, Types::OptionalTimestamp.default(nil)

      # @!attribute [r] tags
      #   @return [Array<String>] Tags associated with the space
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

      # @!attribute [r] likes
      #   @return [Integer, nil] Number of likes/stars
      attribute :likes, Types::OptionalInteger.default(nil)

      # @!attribute [r] author
      #   @return [String, nil] Author/organization name
      attribute :author, Types::OptionalString.default(nil)

      # @!attribute [r] created_at
      #   @return [Time, nil] Repository creation timestamp
      attribute :created_at, Types::OptionalTimestamp.default(nil)

      # @!attribute [r] sdk
      #   @return [String, nil] SDK used (e.g., "gradio", "streamlit", "static")
      attribute :sdk, Types::OptionalString.default(nil)

      # @!attribute [r] runtime
      #   @return [Hash, nil] Runtime information (stage, hardware, etc.)
      attribute :runtime, Types::OptionalHash.default(nil)

      # @!attribute [r] card_data
      #   @return [Hash, nil] Space card metadata
      attribute :card_data, Types::OptionalHash.default(nil)

      # Returns the list of file names in the repository.
      #
      # @return [Array<String>] File names
      def file_names
        return [] if siblings.nil?

        siblings.map { |s| s[:rfilename] || s["rfilename"] }.compact
      end

      # Checks if the space has a specific tag.
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

      # Returns the runtime stage if available.
      #
      # @return [String, nil] Runtime stage (e.g., "RUNNING", "STOPPED")
      def runtime_stage
        runtime&.dig("stage") || runtime&.dig(:stage)
      end

      # Checks if the space is currently running.
      #
      # @return [Boolean] True if running
      def running?
        runtime_stage == "RUNNING"
      end

      # Returns a short description of the space.
      #
      # @return [String] Description string
      def to_s
        parts = [id]
        parts << "(#{sdk})" if sdk
        parts << "[#{runtime_stage}]" if runtime_stage
        parts.join(" ")
      end

      # Returns a detailed inspection string.
      #
      # @return [String] Inspection string
      def inspect
        "#<#{self.class.name} id=#{id.inspect} sdk=#{sdk.inspect} " \
          "stage=#{runtime_stage.inspect}>"
      end
    end
  end
end
