# frozen_string_literal: true

require "pathname"
require "digest"
require "fileutils"
require "json"
require_relative "utils/progress"
require_relative "hf_api"
require_relative "errors"

module DurableHuggingfaceHub
  # File download functionality with caching and ETag support.
  #
  # This module provides utilities for downloading files from the HuggingFace Hub
  # with intelligent caching, resume support, and validation using ETags.
  #
  # @example Download a model file
  #   path = DurableHuggingfaceHub::FileDownload.hf_hub_download(
  #     repo_id: "bert-base-uncased",
  #     filename: "config.json"
  #   )
  #   config = JSON.parse(File.read(path))
  #
  # @example Download with custom cache directory
  #   path = DurableHuggingfaceHub::FileDownload.hf_hub_download(
  #     repo_id: "gpt2",
  #     filename: "pytorch_model.bin",
  #     cache_dir: "/custom/cache"
  #   )
  module FileDownload
    # Default cache directory location
    DEFAULT_CACHE_DIR = Pathname.new(Dir.home).join(".cache", "huggingface", "hub")

    # Metadata file name for cache entries
    METADATA_FILENAME = ".metadata.json"

    # Lock file suffix for atomic operations
    LOCK_SUFFIX = ".lock"

    # Downloads a file from the HuggingFace Hub with caching.
    #
    # This method downloads a file from a HuggingFace Hub repository and caches
    # it locally. It uses ETags to avoid re-downloading unchanged files and
    # supports atomic operations to prevent cache corruption.
    #
    # @param repo_id [String] Repository ID (e.g., "bert-base-uncased")
    # @param filename [String] Path to file in repository
    # @param repo_type [String] Type of repository ("model", "dataset", or "space")
    # @param revision [String, nil] Git revision (branch, tag, or commit SHA)
    # @param cache_dir [String, Pathname, nil] Custom cache directory
    # @param force_download [Boolean] Force re-download even if cached
    # @param token [String, nil] HuggingFace API token
    # @param local_files_only [Boolean] Only use cached files, don't download
    # @param headers [Hash, nil] Additional HTTP headers
    # @param progress [Proc, nil] Progress callback (receives current, total, percentage)
    #
    # @return [Pathname] Path to the downloaded (or cached) file
    #
    # @raise [RepositoryNotFoundError] If repository doesn't exist
    # @raise [EntryNotFoundError] If file doesn't exist in repository
    # @raise [LocalEntryNotFoundError] If local_files_only=true and file not cached
    # @raise [ValidationError] If parameters are invalid
    #
    # @example Basic download
    #   path = FileDownload.hf_hub_download(
    #     repo_id: "bert-base-uncased",
    #     filename: "config.json"
    #   )
    #
    # @example Download specific revision
    #   path = FileDownload.hf_hub_download(
    #     repo_id: "gpt2",
    #     filename: "pytorch_model.bin",
    #     revision: "main"
    #   )
    #
    # @example Force re-download
    #   path = FileDownload.hf_hub_download(
    #     repo_id: "bert-base-uncased",
    #     filename: "config.json",
    #     force_download: true
    #   )
    def self.hf_hub_download(
      repo_id:,
      filename:,
      repo_type: "model",
      revision: nil,
      cache_dir: nil,
      force_download: false,
      token: nil,
      local_files_only: false,
      headers: nil,
      progress: nil
    )
      # Validate inputs
      repo_id = Utils::Validators.validate_repo_id(repo_id)
      filename = Utils::Validators.validate_filename(filename)
      repo_type = Utils::Validators.validate_repo_type(repo_type)
      revision = Utils::Validators.validate_revision(revision) if revision

      # Get cache directory
      cache_dir = resolve_cache_dir(cache_dir)

      # Build storage paths
      storage_folder = get_storage_folder(repo_id, repo_type: repo_type, cache_dir: cache_dir)
      revision ||= "main"

      # Check if we can use local files only
      if local_files_only
        cached_path = find_cached_file(storage_folder, filename, revision)
        if cached_path
          return cached_path
        else
          raise LocalEntryNotFoundError.new(
            "File #{filename} not found in local cache for #{repo_id}@#{revision}. " \
            "Cannot download because local_files_only=true"
          )
        end
      end

      # Get token for authentication
      token = Utils::Auth.get_token(token: token)

      # Download or retrieve from cache
      download_file(
        repo_id: repo_id,
        filename: filename,
        repo_type: repo_type,
        revision: revision,
        storage_folder: storage_folder,
        force_download: force_download,
        token: token,
        headers: headers,
        progress: progress
      )
    end

    # Downloads an entire repository snapshot from the HuggingFace Hub with caching.
    #
    # This method downloads all files from a HuggingFace Hub repository for a given
    # revision and stores them in a local cache directory. It leverages `hf_hub_download`
    # for individual file downloads and supports filtering by patterns.
    #
    # The method implements robust offline fallback: if the Hub is unavailable or network
    # is down, it will try to use locally cached files. It properly handles commit hash
    # resolution for branches and tags.
    #
    # @param repo_id [String] Repository ID (e.g., "bert-base-uncased")
    # @param repo_type [String, Symbol] Type of repository ("model", "dataset", or "space")
    # @param revision [String, nil] Git revision (branch, tag, or commit SHA). Defaults to "main"
    # @param cache_dir [String, Pathname, nil] Custom cache directory
    # @param local_dir [String, Pathname, nil] Custom directory to copy the snapshot to.
    #   If nil, the snapshot will remain in the cache.
    # @param force_download [Boolean] Force re-download even if cached
    # @param token [String, nil] HuggingFace API token
    # @param local_files_only [Boolean] Only use cached files, don't download
    # @param allow_patterns [Array<String>, String, nil] Glob patterns to include (e.g., "*.json", ["*.py", "*.md"])
    # @param ignore_patterns [Array<String>, String, nil] Glob patterns to exclude (e.g., "*.bin", ["*.safetensors"])
    # @param max_workers [Integer] Number of concurrent downloads (default: 8)
    # @param progress [Proc, nil] Progress callback (receives current, total, percentage)
    #
    # @return [Pathname] Path to the downloaded (or cached) snapshot directory
    #
    # @raise [RepositoryNotFoundError] If repository doesn't exist
    # @raise [RevisionNotFoundError] If revision doesn't exist
    # @raise [LocalEntryNotFoundError] If local_files_only=true and files not cached
    # @raise [ValidationError] If parameters are invalid
    #
    # @example Download entire model repository
    #   local_dir = FileDownload.snapshot_download(
    #     repo_id: "gpt2",
    #     revision: "main"
    #   )
    #
    # @example Download only specific file patterns
    #   filtered_dir = FileDownload.snapshot_download(
    #     repo_id: "bert-base-uncased",
    #     allow_patterns: ["*.json", "*.txt"],
    #     ignore_patterns: ["*.bin"]
    #   )
    #
    # @example Download with parallel downloads
    #   snapshot = FileDownload.snapshot_download(
    #     repo_id: "bert-base-uncased",
    #     max_workers: 16
    #   )
    def self.snapshot_download(
      repo_id:,
      repo_type: "model",
      revision: nil,
      cache_dir: nil,
      local_dir: nil,
      force_download: false,
      token: nil,
      local_files_only: false,
      allow_patterns: nil,
      ignore_patterns: nil,
      max_workers: 8,
      progress: nil
    )
      # Validate inputs
      repo_id = Utils::Validators.validate_repo_id(repo_id)
      repo_type = Utils::Validators.validate_repo_type(repo_type)
      revision = Utils::Validators.validate_revision(revision) if revision
      revision ||= "main"

      # Get cache directory and storage folder
      cache_dir = resolve_cache_dir(cache_dir)
      storage_folder = get_storage_folder(repo_id, repo_type: repo_type, cache_dir: cache_dir)

      # Get token for authentication
      token = Utils::Auth.get_token(token: token)

      # Try to fetch repository info from Hub
      repo_info = nil
      api_call_error = nil

      unless local_files_only
        begin
          # Initialize HfApi client
          api = HfApi.new(token: token)
          repo_info = api.repo_info(repo_id, repo_type: repo_type, revision: revision)
        rescue StandardError => e
          # Store error but continue - we might be able to use cached files
          api_call_error = e
        end
      end

      # If we couldn't get repo_info, try to use cached files
      if repo_info.nil?
        # Try to resolve commit hash from revision
        commit_hash = nil

        # Check if revision is already a commit hash
        if revision.match?(/^[0-9a-f]{40}$/)
          commit_hash = revision
        else
          # Try to read commit hash from refs
          ref_file = storage_folder.join("refs", revision)
          if ref_file.exist?
            commit_hash = ref_file.read.strip
          end
        end

        # Try to locate snapshot folder for this commit hash
        if commit_hash && local_dir.nil?
          snapshot_folder = storage_folder.join("snapshots", commit_hash)
          if snapshot_folder.exist? && snapshot_folder.directory?
            # Snapshot folder exists => return it
            return snapshot_folder
          end
        end

        # If local_dir is specified and exists, return it
        if local_dir
          local_dir_path = Utils::Paths.expand_path(local_dir)
          if local_dir_path.exist? && local_dir_path.directory? && !local_dir_path.children.empty?
            warn "Returning existing local_dir #{local_dir_path} as remote repo cannot be accessed"
            return local_dir_path
          end
        end

        # Could not find cached files - raise appropriate error
        if local_files_only
          raise LocalEntryNotFoundError.new(
            "Cannot find an appropriate cached snapshot folder for #{repo_id}@#{revision}. " \
            "To enable downloads, set local_files_only=false"
          )
        elsif api_call_error.is_a?(RepositoryNotFoundError) || api_call_error.is_a?(RevisionNotFoundError)
          raise api_call_error
        else
          raise LocalEntryNotFoundError.new(
            "An error occurred while trying to locate files on the Hub, and we cannot find " \
            "the appropriate snapshot folder for #{repo_id}@#{revision} in the local cache. " \
            "Please check your internet connection and try again. Error: #{api_call_error&.message}"
          )
        end
      end

      # At this point, we have repo_info with a valid commit hash
      commit_hash = repo_info.sha
      raise DurableHuggingfaceHubError, "Repo info must have a commit SHA" unless commit_hash

      # Determine snapshot folder
      snapshot_folder = storage_folder.join("snapshots", commit_hash)

      # Store ref if revision is not a commit hash
      if revision != commit_hash
        update_refs(storage_folder, revision, commit_hash)
      end

      # Get list of files from repo_info
      all_files = if repo_info.respond_to?(:siblings) && repo_info.siblings
        repo_info.siblings.map { |sibling| sibling[:rfilename] || sibling["rfilename"] }.compact
      else
        # Fallback to API call if siblings not available
        api.list_repo_files(repo_id: repo_id, repo_type: repo_type, revision: commit_hash)
      end

      # Filter files based on allow_patterns and ignore_patterns
      filtered_files = Utils::Paths.filter_repo_objects(all_files, allow_patterns: allow_patterns, ignore_patterns: ignore_patterns)

      # Download files (with parallelization if max_workers > 1)
      if max_workers > 1
        download_files_parallel(
          repo_id: repo_id,
          files: filtered_files,
          repo_type: repo_type,
          revision: commit_hash,
          cache_dir: cache_dir,
          force_download: force_download,
          token: token,
          max_workers: max_workers,
          progress: progress
        )
      else
        # Sequential download
        filtered_files.each do |filename|
          hf_hub_download(
            repo_id: repo_id,
            filename: filename,
            repo_type: repo_type,
            revision: commit_hash,
            cache_dir: cache_dir,
            force_download: force_download,
            token: token,
            local_files_only: false,
            progress: progress
          )
        end
      end

      # If local_dir is specified, copy the snapshot there
      if local_dir
        local_dir_path = Utils::Paths.expand_path(local_dir)
        copy_snapshot_to_local_dir(snapshot_folder, local_dir_path)
        return local_dir_path.realpath
      end

      snapshot_folder
    end

    # Gets the cache directory for a repository.
    #
    # @param repo_id [String] Repository ID
    # @param repo_type [String] Type of repository
    # @param cache_dir [String, Pathname, nil] Custom cache directory
    # @return [Pathname] Storage folder path
    def self.get_storage_folder(repo_id, repo_type: "model", cache_dir: nil)
      cache_dir = resolve_cache_dir(cache_dir)

      # Create a unique folder name based on repo_id and type
      # Format: models--namespace--name or models--name
      repo_id_parts = repo_id.split("/")
      if repo_id_parts.length == 2
        folder_name = "#{repo_type}s--#{repo_id_parts[0]}--#{repo_id_parts[1]}"
      else
        folder_name = "#{repo_type}s--#{repo_id}"
      end

      cache_dir.join(folder_name)
    end

    # Resolves the cache directory to use.
    #
    # @param cache_dir [String, Pathname, nil] Custom cache directory
    # @return [Pathname] Resolved cache directory
    def self.resolve_cache_dir(cache_dir)
      if cache_dir
        Utils::Paths.expand_path(cache_dir)
      elsif ENV["HF_HOME"]
        Pathname.new(ENV["HF_HOME"]).join("hub")
      elsif ENV["HUGGINGFACE_HUB_CACHE"]
        Pathname.new(ENV["HUGGINGFACE_HUB_CACHE"])
      else
        DEFAULT_CACHE_DIR
      end
    end

    # Finds a cached file for a specific revision.
    #
    # @param storage_folder [Pathname] Repository storage folder
    # @param filename [String] File path in repository
    # @param revision [String] Git revision
    # @return [Pathname, nil] Path to cached file or nil if not found
    def self.find_cached_file(storage_folder, filename, revision)
      # Look for snapshot folder for this revision
      snapshots_folder = storage_folder.join("snapshots")
      return nil unless snapshots_folder.exist?

      # Try to find by revision folder
      revision_folder = snapshots_folder.join(revision)
      if revision_folder.exist?
        file_path = revision_folder.join(filename)
        return file_path if file_path.exist?
      end

      # Try to find in refs folder
      refs_folder = storage_folder.join("refs")
      if refs_folder.exist?
        ref_file = refs_folder.join(revision)
        if ref_file.exist?
          commit_hash = ref_file.read.strip
          commit_folder = snapshots_folder.join(commit_hash)
          if commit_folder.exist?
            file_path = commit_folder.join(filename)
            return file_path if file_path.exist?
          end
        end
      end

      nil
    end

    # Downloads a file and stores it in the cache.
    #
    # @param repo_id [String] Repository ID
    # @param filename [String] File path in repository
    # @param repo_type [String] Type of repository
    # @param revision [String] Git revision
    # @param storage_folder [Pathname] Repository storage folder
    # @param force_download [Boolean] Force re-download
    # @param token [String, nil] HuggingFace API token
    # @param headers [Hash, nil] Additional HTTP headers
    # @param progress [Proc, nil] Progress callback
    # @return [Pathname] Path to downloaded file
    def self.download_file(
      repo_id:,
      filename:,
      repo_type:,
      revision:,
      storage_folder:,
      force_download:,
      token:,
      headers:,
      progress:
    )
      # Create HTTP client
      client = Utils::HttpClient.new(token: token, headers: headers)

      # Build URL for file
      url_path = "/#{repo_type}s/#{repo_id}/resolve/#{revision}/#{filename}"

      # Get metadata about the file (including ETag and commit hash)
      metadata = get_file_metadata(client, url_path)

      # Determine final storage location
      commit_hash = metadata[:commit_hash] || revision
      blob_path = storage_folder.join("blobs", metadata[:etag])
      snapshot_path = storage_folder.join("snapshots", commit_hash, filename)

       # Check if we already have this file (by ETag or snapshot file)
       unless force_download
         if blob_path.exist? && verify_blob(blob_path, metadata[:etag])
           # File exists in blob storage, create symlink if needed
           ensure_snapshot_link(blob_path, snapshot_path)
           update_refs(storage_folder, revision, commit_hash)
           return snapshot_path
         elsif snapshot_path.exist?
           # File exists in snapshot, assume it's valid
           update_refs(storage_folder, revision, commit_hash)
           return snapshot_path
         end
       end

      # Download the file to blob storage
      download_to_blob(client, url_path, blob_path, metadata, progress)

      # Create snapshot symlink
      ensure_snapshot_link(blob_path, snapshot_path)

      # Update refs
      update_refs(storage_folder, revision, commit_hash)

      snapshot_path
    end

    # Gets metadata about a file from the Hub.
    #
    # @param client [Utils::HttpClient] HTTP client
    # @param url_path [String] URL path to file
    # @return [Hash] Metadata including :etag, :size, :commit_hash
    def self.get_file_metadata(client, url_path)
      response = client.head(url_path)

      # Extract metadata from headers (response is now a Faraday::Response object)
      headers = response.headers
      {
        etag: extract_etag(headers["etag"] || headers["x-linked-etag"]),
        size: headers["x-linked-size"]&.to_i,
        commit_hash: headers["x-repo-commit"]
      }
    end

    # Extracts clean ETag from header value.
    #
    # @param etag [String, nil] Raw ETag header value
    # @return [String, nil] Cleaned ETag
    def self.extract_etag(etag)
      return nil unless etag

      # Remove quotes and W/ prefix
      etag = etag.gsub(/^W\//, "").gsub(/^"/, "").gsub(/"$/, "")
      etag.empty? ? nil : etag
    end

    # Verifies a blob file matches the expected ETag.
    #
    # @param blob_path [Pathname] Path to blob file
    # @param etag [String] Expected ETag
    # @return [Boolean] True if blob is valid
    def self.verify_blob(blob_path, etag)
      return false unless blob_path.exist?

      # First check filename matches ETag (fast check)
      return false unless blob_path.basename.to_s == etag

      # For more robust verification, we could compute the actual ETag
      # from file content, but for now we trust the filename-based approach
      # used by HuggingFace Hub
      true
    end

    # Downloads a file to blob storage.
    #
    # @param client [Utils::HttpClient] HTTP client
    # @param url_path [String] URL path to file
    # @param blob_path [Pathname] Destination blob path
    # @param metadata [Hash] File metadata
    # @param progress [Proc, nil] Progress callback
    def self.download_to_blob(client, url_path, blob_path, metadata, progress)
      # Ensure blobs directory exists
      blob_path.dirname.mkpath

      # Download to temporary file first (atomic operation)
      temp_path = Pathname.new("#{blob_path}.tmp.#{Process.pid}")

      # Create progress tracker
      progress_tracker = if progress
        Utils::Progress.new(total: metadata[:size], callback: progress)
      else
        Utils::NullProgress.new
      end

      begin
        # Download file
        response = client.request(:get, url_path) do |req|
          req.options.on_data = proc do |chunk, _overall_received_bytes, _env|
            File.open(temp_path, "ab") { |f| f.write(chunk) }
            progress_tracker.update(chunk.bytesize)
          end
        end

        # Verify download
        unless temp_path.exist? && temp_path.size.positive?
          raise DurableHuggingfaceHubError, "Download failed: file is empty or missing"
        end

        # Move to final location atomically
        FileUtils.mv(temp_path, blob_path)

        # Mark progress as finished
        progress_tracker.finish

        # Write metadata
        write_blob_metadata(blob_path, metadata)
      ensure
        # Clean up temp file if it still exists
        temp_path.unlink if temp_path.exist?
      end
    end

    # Writes metadata for a blob file.
    #
    # @param blob_path [Pathname] Path to blob file
    # @param metadata [Hash] Metadata to write
    def self.write_blob_metadata(blob_path, metadata)
      metadata_path = Pathname.new("#{blob_path}#{METADATA_FILENAME}")
      metadata_path.write(JSON.pretty_generate(metadata))
    end

    # Ensures a symlink exists from snapshot to blob.
    #
    # @param blob_path [Pathname] Source blob path
    # @param snapshot_path [Pathname] Destination snapshot path
    def self.ensure_snapshot_link(blob_path, snapshot_path)
      # Create snapshot directory if needed
      snapshot_path.dirname.mkpath

      # Remove existing file/link if present
      snapshot_path.unlink if snapshot_path.exist? || snapshot_path.symlink?

      # Create relative symlink
      relative_blob_path = blob_path.relative_path_from(snapshot_path.dirname)
      snapshot_path.make_symlink(relative_blob_path)
    rescue NotImplementedError
      # System doesn't support symlinks, copy instead
      FileUtils.cp(blob_path, snapshot_path)
    end

    # Updates refs to point to the latest commit hash.
    #
    # @param storage_folder [Pathname] Repository storage folder
    # @param revision [String] Revision name (branch/tag)
    # @param commit_hash [String] Commit hash
    def self.update_refs(storage_folder, revision, commit_hash)
      return if revision == commit_hash # Don't create ref for commit hashes

      refs_folder = storage_folder.join("refs")
      refs_folder.mkpath

      ref_file = refs_folder.join(revision)
      ref_file.write(commit_hash)
    end

    # Filters files based on glob patterns.
    #
    # @param files [Array<String>] List of file paths
    # @param allow_patterns [Array<String>, String, nil] Glob patterns to include
    # @param ignore_patterns [Array<String>, String, nil] Glob patterns to exclude
    # @return [Array<String>] Filtered list of files
    def self.filter_repo_files(files, allow_patterns: nil, ignore_patterns: nil)
      filtered = files

      # Apply allow_patterns if specified
      if allow_patterns
        patterns = Array(allow_patterns)
        filtered = filtered.select do |filename|
          patterns.any? { |pattern| File.fnmatch(pattern, filename, File::FNM_PATHNAME) }
        end
      end

      # Apply ignore_patterns if specified
      if ignore_patterns
        patterns = Array(ignore_patterns)
        filtered = filtered.reject do |filename|
          patterns.any? { |pattern| File.fnmatch(pattern, filename, File::FNM_PATHNAME) }
        end
      end

      filtered
    end

    # Downloads multiple files in parallel using threads.
    #
    # @param repo_id [String] Repository ID
    # @param files [Array<String>] List of files to download
    # @param repo_type [String] Repository type
    # @param revision [String] Git revision
    # @param cache_dir [Pathname] Cache directory
    # @param force_download [Boolean] Force re-download
    # @param token [String, nil] Authentication token
    # @param max_workers [Integer] Number of concurrent threads
    # @param progress [Proc, nil] Progress callback
    def self.download_files_parallel(
      repo_id:,
      files:,
      repo_type:,
      revision:,
      cache_dir:,
      force_download:,
      token:,
      max_workers:,
      progress:
    )
      require "thread"

      # Create a queue of files to download
      queue = Queue.new
      files.each { |file| queue << file }

      # Track completed downloads
      completed = 0
      total = files.length
      mutex = Mutex.new

      # Create worker threads
      threads = Array.new([max_workers, files.length].min) do
        Thread.new do
          loop do
            file = begin
              queue.pop(true)
            rescue ThreadError
              break # Queue is empty
            end

            begin
              hf_hub_download(
                repo_id: repo_id,
                filename: file,
                repo_type: repo_type,
                revision: revision,
                cache_dir: cache_dir,
                force_download: force_download,
                token: token,
                local_files_only: false,
                progress: nil # Individual file progress not supported in parallel mode
              )

              mutex.synchronize do
                completed += 1
                progress&.call(completed, total, (completed.to_f / total * 100).round(2)) if progress
              end
            rescue => e
              warn "Failed to download #{file}: #{e.message}"
              # Continue with other files
            end
          end
        end
      end

      # Wait for all threads to complete
      threads.each(&:join)
    end

    # Copies snapshot directory to local directory.
    #
    # @param snapshot_folder [Pathname] Source snapshot folder
    # @param local_dir_path [Pathname] Destination local directory
    def self.copy_snapshot_to_local_dir(snapshot_folder, local_dir_path)
      return unless snapshot_folder.exist?

      FileUtils.mkdir_p(local_dir_path)

      # Copy all files and directories from snapshot to local_dir
      snapshot_folder.children.each do |entry|
        dest = local_dir_path.join(entry.basename)

        if entry.symlink?
          # For symlinks, copy the actual file content
          target = entry.readlink
          target = entry.dirname.join(target) unless target.absolute?

          if target.file?
            FileUtils.cp(target, dest)
          end
        elsif entry.directory?
          FileUtils.cp_r(entry, dest)
        elsif entry.file?
          FileUtils.cp(entry, dest)
        end
      end
    end

    # Try to load a file from cache without downloading.
    #
    # This utility function checks if a file is available in the local cache
    # and returns its path if found. Unlike `hf_hub_download` with `local_files_only=true`,
    # this method returns `nil` instead of raising an error when the file is not cached.
    #
    # @param repo_id [String] Repository ID
    # @param filename [String] File path in repository
    # @param repo_type [String] Type of repository
    # @param revision [String] Git revision
    # @param cache_dir [String, Pathname, nil] Custom cache directory
    # @return [Pathname, nil] Path to cached file, or nil if not found
    #
    # @example Check if file is cached
    #   path = FileDownload.try_to_load_from_cache(
    #     repo_id: "bert-base-uncased",
    #     filename: "config.json",
    #     revision: "main"
    #   )
    #   if path
    #     puts "File is cached at: #{path}"
    #   else
    #     puts "File not in cache"
    #   end
    def self.try_to_load_from_cache(
      repo_id:,
      filename:,
      repo_type: "model",
      revision: "main",
      cache_dir: nil
    )
      begin
        hf_hub_download(
          repo_id: repo_id,
          filename: filename,
          repo_type: repo_type,
          revision: revision,
          cache_dir: cache_dir,
          local_files_only: true
        )
      rescue LocalEntryNotFoundError
        nil
      end
    end

    # Generate the HuggingFace Hub URL for a file in a repository.
    #
    # @param repo_id [String] Repository ID
    # @param filename [String] File path in repository
    # @param repo_type [String] Type of repository
    # @param revision [String] Git revision (defaults to "main")
    # @param endpoint [String, nil] Custom endpoint URL
    # @return [String] Full URL to the file on HuggingFace Hub
    #
    # @example Generate URL for a model file
    #   url = FileDownload.hf_hub_url(
    #     repo_id: "bert-base-uncased",
    #     filename: "config.json"
    #   )
    #   # => "https://huggingface.co/bert-base-uncased/resolve/main/config.json"
    #
    # @example Generate URL for a dataset file
    #   url = FileDownload.hf_hub_url(
    #     repo_id: "squad",
    #     filename: "train.json",
    #     repo_type: "dataset",
    #     revision: "v1.0"
    #   )
    def self.hf_hub_url(
      repo_id:,
      filename:,
      repo_type: "model",
      revision: "main",
      endpoint: nil
    )
      repo_id = Utils::Validators.validate_repo_id(repo_id)
      filename = Utils::Validators.validate_filename(filename)
      repo_type = Utils::Validators.validate_repo_type(repo_type)
      revision = Utils::Validators.validate_revision(revision)

      endpoint ||= DurableHuggingfaceHub.configuration.endpoint
      endpoint = endpoint.chomp("/")

      "#{endpoint}/#{repo_type}s/#{repo_id}/resolve/#{revision}/#{filename}"
    end
  end
end
