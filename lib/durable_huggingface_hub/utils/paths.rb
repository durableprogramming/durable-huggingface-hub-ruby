# frozen_string_literal: true

require "pathname"

module DurableHuggingfaceHub
  module Utils
    # Path manipulation and filtering utilities.
    #
    # This module provides functions for working with file paths,
    # including expansion, filtering, and pattern matching.
    module Paths
      # Expands a path, resolving home directory and environment variables.
      #
      # @param path [String, Pathname] Path to expand
      # @return [Pathname] Expanded path
      #
      # @example
      #   Paths.expand_path("~/models")  # => Pathname("/home/user/models")
      #   Paths.expand_path("$HOME/data")  # => Pathname("/home/user/data")
      def self.expand_path(path)
        path_str = path.to_s

        # Expand environment variables
        path_str = path_str.gsub(/\$([A-Z_][A-Z0-9_]*)|\$\{([A-Z_][A-Z0-9_]*)\}/) do
          key = Regexp.last_match(1) || Regexp.last_match(2)
          ENV[key] || ""
        end

        # Expand home directory
        Pathname.new(path_str).expand_path
      end

      # Filters a list of repository objects (files) based on allow and ignore patterns.
      #
      # This function implements the filtering logic used by HuggingFace Hub for
      # selecting which files to include in operations like snapshot downloads.
      #
      # @param objects [Array<String>, Array<Hash>] List of file paths or file info hashes
      # @param allow_patterns [Array<String>, String, nil] Patterns to allow (globs or regexes)
      # @param ignore_patterns [Array<String>, String, nil] Patterns to ignore (globs or regexes)
      # @param key [String, Symbol, nil] Key to extract path from hash objects
      # @return [Array] Filtered list of objects
      #
      # @example Filter file list with glob patterns
      #   files = ["config.json", "model.safetensors", "README.md", "data/train.csv"]
      #   Paths.filter_repo_objects(files, allow_patterns: ["*.json", "*.safetensors"])
      #   # => ["config.json", "model.safetensors"]
      #
      # @example Filter with ignore patterns
      #   files = ["model.bin", "config.json", "training_log.txt"]
      #   Paths.filter_repo_objects(files, ignore_patterns: ["*.txt"])
      #   # => ["model.bin", "config.json"]
      #
      # @example Filter hash objects
      #   files = [{ path: "config.json" }, { path: "model.bin" }]
      #   Paths.filter_repo_objects(files, allow_patterns: "*.json", key: :path)
      #   # => [{ path: "config.json" }]
      def self.filter_repo_objects(objects, allow_patterns: nil, ignore_patterns: nil, key: nil)
        return objects if objects.nil? || objects.empty?

        # Normalize patterns to arrays
        allow_patterns = normalize_patterns(allow_patterns)
        ignore_patterns = normalize_patterns(ignore_patterns)

        # If no patterns, return all objects
        return objects if allow_patterns.nil? && ignore_patterns.nil?

        objects.select do |obj|
          path = extract_path(obj, key)
          next false if path.nil?

          should_include?(path, allow_patterns: allow_patterns, ignore_patterns: ignore_patterns)
        end
      end

      # Checks if a path should be included based on allow and ignore patterns.
      #
      # @param path [String] File path to check
      # @param allow_patterns [Array<String>, nil] Patterns to allow
      # @param ignore_patterns [Array<String>, nil] Patterns to ignore
      # @return [Boolean] True if path should be included
      #
      # @example
      #   Paths.should_include?("config.json", allow_patterns: ["*.json"])  # => true
      #   Paths.should_include?("data.txt", allow_patterns: ["*.json"])  # => false
      #   Paths.should_include?("temp.log", ignore_patterns: ["*.log"])  # => false
      def self.should_include?(path, allow_patterns: nil, ignore_patterns: nil)
        # If ignore patterns specified and path matches, exclude it
        if ignore_patterns && matches_any_pattern?(path, ignore_patterns)
          return false
        end

        # If allow patterns specified, path must match at least one
        if allow_patterns
          return matches_any_pattern?(path, allow_patterns)
        end

        # If no allow patterns, include by default (unless already ignored above)
        true
      end

      # Checks if a path matches any of the given patterns.
      #
      # @param path [String] File path to check
      # @param patterns [Array<String>] Glob or regex patterns
      # @return [Boolean] True if path matches any pattern
      #
      # @example
      #   Paths.matches_any_pattern?("config.json", ["*.json", "*.yaml"])  # => true
      #   Paths.matches_any_pattern?("data.txt", ["*.json", "*.yaml"])  # => false
      def self.matches_any_pattern?(path, patterns)
        return false if patterns.nil? || patterns.empty?

        patterns.any? { |pattern| matches_pattern?(path, pattern) }
      end

      # Checks if a path matches a single pattern.
      #
      # Supports both glob patterns and regular expressions.
      #
      # @param path [String] File path to check
      # @param pattern [String, Regexp] Glob pattern or regex
      # @return [Boolean] True if path matches pattern
      #
      # @example Glob patterns
      #   Paths.matches_pattern?("config.json", "*.json")  # => true
      #   Paths.matches_pattern?("data/train.csv", "data/*.csv")  # => true
      #   Paths.matches_pattern?("model.bin", "*.json")  # => false
      #
      # @example Regex patterns
      #   Paths.matches_pattern?("config.json", /\.json$/)  # => true
      def self.matches_pattern?(path, pattern)
        case pattern
        when Regexp
          !pattern.match(path).nil?
        when String
          # Convert glob pattern to regex
          File.fnmatch?(pattern, path, File::FNM_PATHNAME | File::FNM_EXTGLOB)
        else
          false
        end
      end

      # Sanitizes a filename by removing or replacing unsafe characters.
      #
      # @param filename [String] Filename to sanitize
      # @return [String] Sanitized filename
      #
      # @example
      #   Paths.sanitize_filename("my file!.txt")  # => "my_file_.txt"
      #   Paths.sanitize_filename("test/file.json")  # => "test_file.json"
      def self.sanitize_filename(filename)
        # Replace path separators with underscores
        sanitized = filename.gsub(%r{[/\\]}, "_")

        # Replace spaces with underscores
        sanitized = sanitized.gsub(/\s/, "_")

        # Replace other problematic characters
        sanitized.gsub(/[<>:"|?*]/, "_")
      end

      # Joins path components safely, ensuring no path traversal.
      #
      # @param base [String, Pathname] Base path
      # @param *parts [String] Path components to join
      # @return [Pathname] Joined path
      # @raise [ValidationError] If result would escape base path
      #
      # @example
      #   Paths.safe_join("/cache", "models", "bert")
      #   # => Pathname("/cache/models/bert")
      def self.safe_join(base, *parts)
        # Validate that no part is an absolute path
        parts.each do |part|
          if part.to_s.start_with?("/")
            raise ValidationError.new(
              "path",
              "Path component cannot be absolute: #{part}"
            )
          end
        end

        base_path = Pathname.new(base).expand_path
        joined_path = parts.reduce(base_path) { |path, part| path.join(part) }
        final_path = joined_path.expand_path

        # Ensure the final path is within the base path
        unless final_path.to_s.start_with?(base_path.to_s)
          raise ValidationError.new(
            "path",
            "Path traversal detected: result would escape base directory"
          )
        end

        final_path
      end

      private

      # Normalizes pattern input to an array.
      #
      # @param patterns [Array, String, nil] Patterns
      # @return [Array<String>, nil] Normalized patterns
      def self.normalize_patterns(patterns)
        return nil if patterns.nil?
        return [patterns] if patterns.is_a?(String) || patterns.is_a?(Regexp)
        return patterns if patterns.is_a?(Array)

        nil
      end

      # Extracts path from an object (string or hash).
      #
      # @param obj [String, Hash] Object
      # @param key [String, Symbol, nil] Key for hash extraction
      # @return [String, nil] Extracted path
      def self.extract_path(obj, key)
        case obj
        when String
          obj
        when Hash
          key ? (obj[key] || obj[key.to_s] || obj[key.to_sym]) : nil
        else
          nil
        end
      end
    end
  end
end
