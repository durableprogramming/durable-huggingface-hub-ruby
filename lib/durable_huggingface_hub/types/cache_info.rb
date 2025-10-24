# frozen_string_literal: true

require_relative "../types"

module DurableHuggingfaceHub
  module Types
    # Information about a cached file.
    #
    # Represents a single file in the cache with its metadata.
    #
    # @example
    #   cached_file = CachedFileInfo.new(
    #     file_path: Pathname.new("/cache/blobs/abc123"),
    #     size: 1024,
    #     etag: "abc123",
    #     commit_hash: "def456",
    #     last_accessed: Time.now,
    #     last_modified: Time.now
    #   )
    class CachedFileInfo < DurableHuggingfaceHub::Struct
      include Loadable

      # @!attribute [r] file_path
      #   Path to the cached file
      #   @return [Pathname]
      attribute :file_path, Types::PathnameType

      # @!attribute [r] size
      #   Size of the file in bytes
      #   @return [Integer]
      attribute :size, Types::Integer

      # @!attribute [r] etag
      #   ETag of the file (used for cache validation)
      #   @return [String, nil]
      attribute :etag, Types::OptionalString

      # @!attribute [r] commit_hash
      #   Git commit hash this file belongs to
      #   @return [String, nil]
      attribute :commit_hash, Types::OptionalString.default(nil)

      # @!attribute [r] last_accessed
      #   When the file was last accessed
      #   @return [Time, nil]
      attribute :last_accessed, Types::OptionalTimestamp.default(nil)

      # @!attribute [r] last_modified
      #   When the file was last modified
      #   @return [Time, nil]
      attribute :last_modified, Types::OptionalTimestamp.default(nil)

      # Human-readable size string.
      #
      # @return [String] Size formatted as human-readable string (e.g., "1.2 MB")
      def size_str
        units = ["B", "KB", "MB", "GB", "TB"]
        size = self.size.to_f
        unit_index = 0

        while size >= 1024 && unit_index < units.length - 1
          size /= 1024.0
          unit_index += 1
        end

        format("%.2f %s", size, units[unit_index])
      end
    end

    # Information about a cached repository revision.
    #
    # Represents a specific revision (commit, branch, or tag) of a repository in the cache.
    #
    # @example
    #   revision = CachedRevisionInfo.new(
    #     commit_hash: "abc123",
    #     refs: ["main", "v1.0"],
    #     files: [cached_file_info1, cached_file_info2],
    #     size: 2048,
    #     last_modified: Time.now
    #   )
    class CachedRevisionInfo < DurableHuggingfaceHub::Struct
      include Loadable

      # @!attribute [r] commit_hash
      #   Git commit hash for this revision
      #   @return [String]
      attribute :commit_hash, Types::String

      # @!attribute [r] refs
      #   List of refs (branches/tags) pointing to this commit
      #   @return [Array<String>]
      attribute :refs, Types::StringArray

      # @!attribute [r] files
      #   List of cached files in this revision
      #   @return [Array<CachedFileInfo>]
      attribute :files, Types::Array.of(CachedFileInfo)

      # @!attribute [r] size
      #   Total size of all files in this revision
      #   @return [Integer]
      attribute :size, Types::Integer

      # @!attribute [r] last_modified
      #   When this revision was last modified
      #   @return [Time, nil]
      attribute :last_modified, Types::OptionalTimestamp.default(nil)

      # Human-readable size string.
      #
      # @return [String] Size formatted as human-readable string
      def size_str
        units = ["B", "KB", "MB", "GB", "TB"]
        size = self.size.to_f
        unit_index = 0

        while size >= 1024 && unit_index < units.length - 1
          size /= 1024.0
          unit_index += 1
        end

        format("%.2f %s", size, units[unit_index])
      end

      # Number of files in this revision.
      #
      # @return [Integer] File count
      def file_count
        files.length
      end
    end

    # Information about a cached repository.
    #
    # Represents a repository in the cache with all its revisions and files.
    #
    # @example
    #   repo = CachedRepoInfo.new(
    #     repo_id: "bert-base-uncased",
    #     repo_type: "model",
    #     revisions: [revision_info1, revision_info2],
    #     size: 1048576,
    #     last_accessed: Time.now,
    #     last_modified: Time.now
    #   )
    class CachedRepoInfo < DurableHuggingfaceHub::Struct
      include Loadable

      # @!attribute [r] repo_id
      #   Repository identifier
      #   @return [String]
      attribute :repo_id, Types::String

      # @!attribute [r] repo_type
      #   Type of repository ("model", "dataset", or "space")
      #   @return [String]
      attribute :repo_type, Types::String

      # @!attribute [r] revisions
      #   List of cached revisions for this repository
      #   @return [Array<CachedRevisionInfo>]
      attribute :revisions, Types::Array.of(CachedRevisionInfo)

      # @!attribute [r] size
      #   Total size of all revisions in this repository
      #   @return [Integer]
      attribute :size, Types::Integer

      # @!attribute [r] last_accessed
      #   When the repository was last accessed
      #   @return [Time, nil]
      attribute :last_accessed, Types::OptionalTimestamp.default(nil)

      # @!attribute [r] last_modified
      #   When the repository was last modified
      #   @return [Time, nil]
      attribute :last_modified, Types::OptionalTimestamp.default(nil)

      # Human-readable size string.
      #
      # @return [String] Size formatted as human-readable string
      def size_str
        units = ["B", "KB", "MB", "GB", "TB"]
        size = self.size.to_f
        unit_index = 0

        while size >= 1024 && unit_index < units.length - 1
          size /= 1024.0
          unit_index += 1
        end

        format("%.2f %s", size, units[unit_index])
      end

      # Number of revisions cached for this repository.
      #
      # @return [Integer] Revision count
      def revision_count
        revisions.length
      end

      # Total number of files across all revisions.
      #
      # @return [Integer] Total file count
      def file_count
        revisions.sum(&:file_count)
      end
    end

    # Comprehensive cache information.
    #
    # Contains information about the entire cache directory including all repositories.
    #
    # @example
    #   cache_info = HFCacheInfo.new(
    #     cache_dir: Pathname.new("/cache"),
    #     repos: [repo_info1, repo_info2],
    #     size: 2097152
    #   )
    class HFCacheInfo < DurableHuggingfaceHub::Struct
      include Loadable

      # @!attribute [r] cache_dir
      #   Path to the cache directory
      #   @return [Pathname]
      attribute :cache_dir, Types::PathnameType

      # @!attribute [r] repos
      #   List of cached repositories
      #   @return [Array<CachedRepoInfo>]
      attribute :repos, Types::Array.of(CachedRepoInfo)

      # @!attribute [r] size
      #   Total size of the cache in bytes
      #   @return [Integer]
      attribute :size, Types::Integer

      # Human-readable size string.
      #
      # @return [String] Size formatted as human-readable string
      def size_str
        units = ["B", "KB", "MB", "GB", "TB"]
        size = self.size.to_f
        unit_index = 0

        while size >= 1024 && unit_index < units.length - 1
          size /= 1024.0
          unit_index += 1
        end

        format("%.2f %s", size, units[unit_index])
      end

      # Number of repositories in the cache.
      #
      # @return [Integer] Repository count
      def repo_count
        repos.length
      end

      # Total number of revisions across all repositories.
      #
      # @return [Integer] Total revision count
      def revision_count
        repos.sum(&:revision_count)
      end

      # Total number of files across all repositories and revisions.
      #
      # @return [Integer] Total file count
      def file_count
        repos.sum(&:file_count)
      end

      # Get repositories sorted by size (largest first).
      #
      # @return [Array<CachedRepoInfo>] Repositories sorted by size
      def repos_by_size
        repos.sort_by { |repo| -repo.size }
      end

      # Get repositories sorted by last accessed time (most recent first).
      #
      # @return [Array<CachedRepoInfo>] Repositories sorted by access time
      def repos_by_last_accessed
        repos.compact.sort_by { |repo| repo.last_accessed || Time.at(0) }.reverse
      end

      # Get repositories sorted by last modified time (most recent first).
      #
      # @return [Array<CachedRepoInfo>] Repositories sorted by modification time
      def repos_by_last_modified
        repos.compact.sort_by { |repo| repo.last_modified || Time.at(0) }.reverse
      end
    end
  end
end
