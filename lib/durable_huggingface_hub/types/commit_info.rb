# frozen_string_literal: true

require_relative "../types"

module DurableHuggingfaceHub
  module Types
    # Information about a Git commit in a HuggingFace Hub repository.
    #
    # @example Creating a CommitInfo from API response
    #   commit_info = CommitInfo.from_hash({
    #     "oid" => "a1b2c3d4e5f6...",
    #     "title" => "Update model weights",
    #     "message" => "Update model weights\n\nImproved accuracy",
    #     "date" => "2024-01-15T10:30:00Z"
    #   })
    #
    # @example Accessing commit information
    #   commit_info.oid    # => "a1b2c3d4e5f6..."
    #   commit_info.title  # => "Update model weights"
    class CommitInfo < DurableHuggingfaceHub::Struct
      include Loadable

      # @!attribute [r] oid
      #   @return [String] Commit OID (Git SHA)
      attribute :oid, Types::String

      # @!attribute [r] title
      #   @return [String] Commit title (first line of message)
      attribute :title, Types::String

      # @!attribute [r] message
      #   @return [String, nil] Full commit message
      attribute :message, Types::OptionalString.default(nil)

      # @!attribute [r] date
      #   @return [Time, nil] Commit timestamp
      attribute :date, Types::OptionalTimestamp.default(nil)

      # @!attribute [r] authors
      #   @return [Array<String>, nil] Commit authors
      attribute :authors, Types::OptionalStringArray.default(nil)

      # @!attribute [r] commit_url
      #   @return [String, nil] URL to view the commit
      attribute :commit_url, Types::OptionalString.default(nil)

      # @!attribute [r] commit_message
      #   @return [String, nil] Alias for message (API compatibility)
      attribute :commit_message, Types::OptionalString.default(nil)

      # Returns the short OID (first 7 characters).
      #
      # @return [String] Short OID
      def short_oid
        oid[0, 7]
      end

      # Returns the commit message (preferring message over commit_message).
      #
      # @return [String, nil] Commit message
      def full_message
        message || commit_message
      end

      # Returns a short description of the commit.
      #
      # @return [String] Description string
      def to_s
        "#{short_oid}: #{title}"
      end

      # Returns a detailed inspection string.
      #
      # @return [String] Inspection string
      def inspect
        "#<#{self.class.name} oid=#{short_oid.inspect} title=#{title[0, 50].inspect}>"
      end
    end

    # Information about a Git reference (branch or tag) in a HuggingFace Hub repository.
    #
    # @example Creating a GitRefInfo from API response
    #   ref_info = GitRefInfo.from_hash({
    #     "name" => "main",
    #     "ref" => "refs/heads/main",
    #     "targetCommit" => "a1b2c3d4e5f6..."
    #   })
    #
    # @example Accessing ref information
    #   ref_info.name           # => "main"
    #   ref_info.target_commit  # => "a1b2c3d4e5f6..."
    class GitRefInfo < DurableHuggingfaceHub::Struct
      include Loadable

      # @!attribute [r] name
      #   @return [String] Reference name (e.g., "main", "v1.0.0")
      attribute :name, Types::String

      # @!attribute [r] ref
      #   @return [String] Full reference path (e.g., "refs/heads/main")
      attribute :ref, Types::String

      # @!attribute [r] target_commit
      #   @return [String, nil] Target commit OID
      attribute :target_commit, Types::OptionalString.default(nil)



      # Checks if this is a branch reference.
      #
      # @return [Boolean] True if branch
      def branch?
        ref.start_with?("refs/heads/")
      end

      # Checks if this is a tag reference.
      #
      # @return [Boolean] True if tag
      def tag?
        ref.start_with?("refs/tags/")
      end

      # Returns the reference type.
      #
      # @return [String] "branch", "tag", or "unknown"
      def ref_type
        return "branch" if branch?
        return "tag" if tag?

        "unknown"
      end

      # Returns a short description of the ref.
      #
      # @return [String] Description string
      def to_s
        "#{ref_type}: #{name}"
      end

      # Returns a detailed inspection string.
      #
      # @return [String] Inspection string
      def inspect
        "#<#{self.class.name} name=#{name.inspect} type=#{ref_type} " \
          "commit=#{target_commit&.[](0, 7).inspect}>"
      end
    end
  end
end
