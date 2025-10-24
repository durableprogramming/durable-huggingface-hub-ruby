# frozen_string_literal: true

require "pathname"
require "fileutils"
require_relative "types"
require_relative "file_download"

module DurableHuggingfaceHub
  module Cache
    # Scans the cache directory and returns comprehensive information about cached content.
    #
    # This method analyzes the cache structure and provides detailed information
    # about all cached repositories, revisions, and files.
    #
    # @param cache_dir [String, Pathname, nil] Custom cache directory path.
    #   If nil, uses the default cache directory.
    #
    # @return [DurableHuggingfaceHub::Types::HFCacheInfo] Comprehensive cache information
    #
    # @raise [ArgumentError] If cache_dir is invalid
    #
    # @example Scan default cache directory
    #   cache_info = DurableHuggingfaceHub.scan_cache_dir
    #
    # @example Scan custom cache directory
    #   cache_info = DurableHuggingfaceHub.scan_cache_dir(cache_dir: "/custom/cache")
    def self.scan_cache_dir(cache_dir: nil)
      cache_dir = FileDownload.resolve_cache_dir(cache_dir)

      unless cache_dir.exist?
        # Return empty cache info if directory doesn't exist
        return DurableHuggingfaceHub::Types::HFCacheInfo.new(
          cache_dir: cache_dir,
          repos: [],
          size: 0
        )
      end

      repos = []
      total_size = 0

      # Scan each repository directory
      cache_dir.each_child do |repo_dir|
        next unless repo_dir.directory?

        repo_info = scan_repository(repo_dir)
        next unless repo_info

        repos << repo_info
        total_size += repo_info.size
      end

      DurableHuggingfaceHub::Types::HFCacheInfo.new(
        cache_dir: cache_dir,
        repos: repos,
        size: total_size
      )
    end

    # Scans a single repository directory and returns repository information.
    #
    # @param repo_dir [Pathname] Repository directory to scan
    # @return [DurableHuggingfaceHub::Types::CachedRepoInfo, nil] Repository info or nil if invalid
    def self.scan_repository(repo_dir)
      # Parse repo_id and repo_type from directory name
      # Format: {repo_type}s--{namespace}--{name} or {repo_type}s--{name}
      dir_name = repo_dir.basename.to_s
      match = dir_name.match(/^(\w+)s--(.+)$/)
      return nil unless match

      repo_type = match[1] # "model", "dataset", or "space"
      repo_id_part = match[2]

      # Convert back to repo_id format (handle both namespace/name and just name)
      if repo_id_part.include?("--")
        repo_id = repo_id_part.gsub("--", "/")
      else
        repo_id = repo_id_part
      end

      revisions = []
      total_size = 0
      last_accessed = nil
      last_modified = nil

      # Scan snapshots directory
      snapshots_dir = repo_dir.join("snapshots")
      if snapshots_dir.exist?
        snapshots_dir.each_child do |revision_dir|
          next unless revision_dir.directory?

          revision_info = scan_revision(repo_dir, revision_dir, repo_type)
          next unless revision_info

          revisions << revision_info
          total_size += revision_info.size

          # Track last accessed/modified times
          if revision_info.last_modified
            last_modified = [last_modified, revision_info.last_modified].compact.max
          end

          revision_info.files.each do |file_info|
            if file_info.last_accessed
              last_accessed = [last_accessed, file_info.last_accessed].compact.max
            end
          end
        end
      end

      return nil if revisions.empty?

      DurableHuggingfaceHub::Types::CachedRepoInfo.new(
        repo_id: repo_id,
        repo_type: repo_type,
        revisions: revisions,
        size: total_size,
        last_accessed: last_accessed,
        last_modified: last_modified
      )
    end

    # Scans a revision directory and returns revision information.
    #
    # @param repo_dir [Pathname] Repository directory
    # @param revision_dir [Pathname] Revision directory to scan
    # @param repo_type [String] Type of repository
    # @return [DurableHuggingfaceHub::Types::CachedRevisionInfo, nil] Revision info or nil if invalid
    def self.scan_revision(repo_dir, revision_dir, repo_type)
      commit_hash = revision_dir.basename.to_s
      files = []
      total_size = 0
      last_modified = nil

      # Get refs pointing to this commit
      refs = get_refs_for_commit(repo_dir, commit_hash)

      # Scan all files in the revision
      revision_dir.glob("**/*") do |file_path|
        next if file_path.directory?

        begin
          file_info = scan_file(file_path, commit_hash)
          files << file_info
          total_size += file_info.size

          if file_info.last_modified
            last_modified = [last_modified, file_info.last_modified].compact.max
          end
        rescue => e
          # Skip files that can't be analyzed
          next
        end
      end

      return nil if files.empty?

      DurableHuggingfaceHub::Types::CachedRevisionInfo.new(
        commit_hash: commit_hash,
        refs: refs,
        files: files,
        size: total_size,
        last_modified: last_modified
      )
    end

    # Scans a single file and returns file information.
    #
    # @param file_path [Pathname] Path to the file
    # @param commit_hash [String] Commit hash this file belongs to
    # @return [DurableHuggingfaceHub::Types::CachedFileInfo] File information
    def self.scan_file(file_path, commit_hash)
      # Get file stats, handling broken symlinks
      stat = begin
        file_path.stat
      rescue Errno::ENOENT
        # For broken symlinks, use lstat to get link info
        file_path.lstat
      end

      # Try to get ETag from blob metadata if this is a symlink
      etag = nil
      if file_path.symlink?
        begin
          target_path = file_path.readlink
          if target_path.absolute?
            # This should point to a blob file
            blob_name = target_path.basename.to_s
            etag = blob_name if blob_name.match?(/^[a-f0-9]{40,}$/) # SHA-like hash
          end
        rescue Errno::ENOENT
          # Broken symlink, no ETag available
          etag = nil
        end
      else
        # For direct files, we might not have ETag info
        etag = nil
      end

      # Build attributes hash
      attrs = {
        file_path: file_path,
        size: stat.size,
        etag: etag,
        commit_hash: commit_hash,
        last_accessed: stat.atime,
        last_modified: stat.mtime
      }

      DurableHuggingfaceHub::Types::CachedFileInfo.new(attrs)
    end

    # Gets refs (branches/tags) that point to a specific commit.
    #
    # @param repo_dir [Pathname] Repository directory
    # @param commit_hash [String] Commit hash to find refs for
    # @return [Array<String>] List of refs pointing to this commit
    def self.get_refs_for_commit(repo_dir, commit_hash)
      refs = []
      refs_dir = repo_dir.join("refs")

      return refs unless refs_dir.exist?

      refs_dir.glob("**/*") do |ref_file|
        next if ref_file.directory?

        begin
          ref_commit = ref_file.read.strip
          if ref_commit == commit_hash
            # Get relative path from refs directory
            rel_path = ref_file.relative_path_from(refs_dir).to_s
            refs << rel_path
          end
        rescue
          # Skip unreadable ref files
          next
        end
      end

      refs
    end

    # Get the path to cached assets for a repository.
    #
    # This utility function helps locate cached files and directories for a specific repository.
    #
    # @param repo_id [String] Repository ID
    # @param repo_type [String] Type of repository ("model", "dataset", or "space")
    # @param cache_dir [String, Pathname, nil] Custom cache directory
    # @return [Pathname, nil] Path to the repository's cache directory, or nil if not found
    #
    # @example Get cache path for a model
    #   cache_path = DurableHuggingfaceHub::Cache.cached_assets_path(
    #     repo_id: "bert-base-uncased",
    #     repo_type: "model"
    #   )
    #   puts cache_path # /home/user/.cache/huggingface/hub/models--bert-base-uncased
    def self.cached_assets_path(repo_id:, repo_type: "model", cache_dir: nil)
      DurableHuggingfaceHub::Utils::Validators.validate_repo_id(repo_id)
      repo_type = DurableHuggingfaceHub::Utils::Validators.validate_repo_type(repo_type)

      cache_dir = FileDownload.resolve_cache_dir(cache_dir)

      # Build the expected repository directory name
      repo_id_parts = repo_id.split("/")
      if repo_id_parts.length == 2
        folder_name = "#{repo_type}s--#{repo_id_parts[0]}--#{repo_id_parts[1]}"
      else
        folder_name = "#{repo_type}s--#{repo_id}"
      end

      repo_path = cache_dir.join(folder_name)
      repo_path.exist? ? repo_path : nil
    end

    # Strategy for deleting cache entries.
    #
    # This class provides a safe way to plan and execute cache cleanup operations.
    # It allows previewing what will be deleted before actually performing the deletion.
    #
    # @example Delete specific repositories
    #   cache_info = DurableHuggingfaceHub.scan_cache_dir
    #   repos_to_delete = cache_info.repos.select { |repo| repo.size > 1_000_000_000 } # > 1GB
    #   strategy = DeleteCacheStrategy.new(repos: repos_to_delete)
    #   puts "Will delete #{strategy.size_to_delete_str}"
    #   strategy.execute
    #
    # @example Delete old revisions
    #   old_revisions = cache_info.repos.flat_map do |repo|
    #     repo.revisions.select { |rev| rev.last_accessed < 30.days.ago }
    #   end
    #   strategy = DeleteCacheStrategy.new(revisions: old_revisions)
    #   strategy.execute
    class DeleteCacheStrategy
      # @return [Array<DurableHuggingfaceHub::Types::CachedRepoInfo>] Repositories to delete
      attr_reader :repos

      # @return [Array<DurableHuggingfaceHub::Types::CachedRevisionInfo>] Revisions to delete
      attr_reader :revisions

      # @return [Array<DurableHuggingfaceHub::Types::CachedFileInfo>] Individual files to delete
      attr_reader :files

      # Initialize a new delete strategy.
      #
      # @param cache_dir [Pathname] The cache directory
      # @param repos [Array<DurableHuggingfaceHub::Types::CachedRepoInfo>] Repositories to delete
      # @param revisions [Array<DurableHuggingfaceHub::Types::CachedRevisionInfo>] Revisions to delete
      # @param files [Array<DurableHuggingfaceHub::Types::CachedFileInfo>] Individual files to delete
      def initialize(cache_dir:, repos: [], revisions: [], files: [])
        @cache_dir = cache_dir
        @repos = repos
        @revisions = revisions
        @files = files
      end

      # Total size that will be deleted in bytes.
      #
      # @return [Integer] Size in bytes
      def size_to_delete
        @repos.sum(&:size) + @revisions.sum(&:size) + @files.sum(&:size)
      end

      # Human-readable size string for what will be deleted.
      #
      # @return [String] Size formatted as human-readable string
      def size_to_delete_str
        units = ["B", "KB", "MB", "GB", "TB"]
        size = size_to_delete.to_f
        unit_index = 0

        while size >= 1024 && unit_index < units.length - 1
          size /= 1024.0
          unit_index += 1
        end

        format("%.1f %s", size, units[unit_index])
      end

      # Number of repositories that will be deleted.
      #
      # @return [Integer] Repository count
      def repo_count
        @repos.length
      end

      # Number of revisions that will be deleted.
      #
      # @return [Integer] Revision count
      def revision_count
        @revisions.length
      end

      # Number of files that will be deleted.
      #
      # @return [Integer] File count
      def file_count
        @files.length
      end

      # Preview what will be deleted.
      #
      # @return [String] Human-readable summary of what will be deleted
      def preview
        summary = []
        has_items = repo_count.positive? || revision_count.positive? || file_count.positive?

        if has_items
          summary << "Will delete:"
          summary << "  #{repo_count} repositories" if repo_count.positive?
          summary << "  #{revision_count} revisions" if revision_count.positive?
          summary << "  #{file_count} files" if file_count.positive?
          summary << "Total size: #{size_to_delete_str}"

          if repo_count.positive?
            summary << ""
            summary << "Repositories:"
            @repos.each { |repo| summary << "  #{repo.repo_id} (#{repo.size_str})" }
          end
        end

        summary.join("\n")
      end

      # Execute the deletion strategy.
      #
      # This method will delete all specified repositories, revisions, and files.
      # Use with caution - deletions are permanent.
      #
      # @return [Boolean] True if successful
      def execute
        # Delete individual files first
        @files.each do |file_info|
          delete_file_safely(file_info.file_path)
        end

        # Delete revisions
        @revisions.each do |revision_info|
          delete_revision_safely(revision_info)
        end

        # Delete entire repositories
        @repos.each do |repo_info|
          delete_repository_safely(repo_info)
        end

        true
      end

      private

      # Safely delete a file.
      #
      # @param file_path [Pathname] Path to file to delete
      def delete_file_safely(file_path)
        return unless file_path.exist?

        # If it's a symlink, just remove the symlink
        if file_path.symlink?
          file_path.unlink
        else
          # For regular files, remove them
          file_path.unlink
        end
      rescue => e
        # Log error but continue with other deletions
        warn "Failed to delete #{file_path}: #{e.message}"
      end

      # Safely delete a revision.
      #
      # @param revision_info [DurableHuggingfaceHub::Types::CachedRevisionInfo] Revision to delete
      def delete_revision_safely(revision_info)
        # Find the revision directory
        repo_dir = find_repo_dir_for_revision(revision_info)
        return unless repo_dir

        revision_dir = repo_dir.join("snapshots", revision_info.commit_hash)
        return unless revision_dir.exist?

        # Remove the entire revision directory
        FileUtils.rm_rf(revision_dir)

        # Clean up refs that pointed to this revision
        cleanup_refs_for_revision(repo_dir, revision_info.commit_hash)
      rescue => e
        warn "Failed to delete revision #{revision_info.commit_hash}: #{e.message}"
      end

      # Safely delete an entire repository.
      #
      # @param repo_info [DurableHuggingfaceHub::Types::CachedRepoInfo] Repository to delete
      def delete_repository_safely(repo_info)
        # Find the repository directory
        repo_dir_name = "#{repo_info.repo_type}s--#{repo_info.repo_id.gsub('/', '--')}"
        repo_dir = @cache_dir.join(repo_dir_name)

        return unless repo_dir.exist?

        # Remove the entire repository directory
        FileUtils.rm_rf(repo_dir)
      rescue => e
        warn "Failed to delete repository #{repo_info.repo_id}: #{e.message}"
      end

      # Find repository directory for a revision.
      #
      # @param revision_info [DurableHuggingfaceHub::Types::CachedRevisionInfo] Revision info
      # @return [Pathname, nil] Repository directory or nil if not found
      def find_repo_dir_for_revision(revision_info)
        # This is a simplified implementation - in practice we'd need to track
        # which repository each revision belongs to
        @cache_dir.each_child do |repo_dir|
          next unless repo_dir.directory?

          snapshots_dir = repo_dir.join("snapshots")
          next unless snapshots_dir.exist?

          revision_dir = snapshots_dir.join(revision_info.commit_hash)
          return repo_dir if revision_dir.exist?
        end

        nil
      end

      # Clean up refs that pointed to a deleted revision.
      #
      # @param repo_dir [Pathname] Repository directory
      # @param commit_hash [String] Commit hash that was deleted
      def cleanup_refs_for_revision(repo_dir, commit_hash)
        refs_dir = repo_dir.join("refs")
        return unless refs_dir.exist?

        refs_dir.glob("**/*") do |ref_file|
          next if ref_file.directory?

          begin
            ref_commit = ref_file.read.strip
            ref_file.unlink if ref_commit == commit_hash
          rescue
            # Skip unreadable ref files
            next
          end
        end
      end
    end
  end
end
