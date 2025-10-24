# frozen_string_literal: true

module DurableHuggingfaceHub
  module Utils
    # Input validation utilities for HuggingFace Hub parameters.
    #
    # This module provides validation functions for repository IDs, revisions,
    # filenames, and other user inputs to ensure they meet HuggingFace Hub requirements.
    module Validators
      # Maximum length for repository ID
      MAX_REPO_ID_LENGTH = 96

       # Validates a repository ID format.
       #
       # Rules:
       # - Between 1 and 96 characters
       # - Either "repo_name" or "namespace/repo_name"
       # - Contains only [a-zA-Z0-9] or "-", "_", "."
       # - Cannot have "--" or ".." sequences
       # - Cannot end with ".git"
       # - Name parts cannot start or end with ".", "-", or "_"
       #
       # @param repo_id [String] Repository ID to validate
       # @param repo_type [String, nil] Repository type (optional, for error messages)
       # @return [String] The validated repo_id
       # @raise [ValidationError] If repo_id is invalid
       #
       # @example Valid repository IDs
       #   Validators.validate_repo_id("bert-base-uncased")
       #   Validators.validate_repo_id("huggingface/transformers")
       #   Validators.validate_repo_id("my-org/my.model-v2")
       #
       # @example Invalid repository IDs
       #   Validators.validate_repo_id("")  # raises ValidationError
       #   Validators.validate_repo_id("foo--bar")  # raises ValidationError
       #   Validators.validate_repo_id("foo.git")  # raises ValidationError
       def self.validate_repo_id(repo_id, repo_type: nil)
         if repo_id.nil?
           raise ValidationError.new("repo_id", "Repository ID cannot be empty")
         end

         unless repo_id.is_a?(String)
           raise ValidationError.new("repo_id", "Repository ID must be a string, not #{repo_id.class}: '#{repo_id}'")
         end

         if repo_id.empty?
           raise ValidationError.new("repo_id", "Repository ID cannot be empty")
         end

         if repo_id.length > MAX_REPO_ID_LENGTH
           raise ValidationError.new("repo_id", "Repository ID is too long (max #{MAX_REPO_ID_LENGTH} characters)")
         end

         # Check for multiple slashes
         if repo_id.count("/") > 1
           raise ValidationError.new("repo_id", "Repository ID must be in format 'repo_name' or 'namespace/repo_name': '#{repo_id}'")
         end

         # Check for "--" and ".." sequences
         if repo_id.include?("--") || repo_id.include?("..")
           raise ValidationError.new("repo_id", "Cannot have -- or .. in repo_id: '#{repo_id}'")
         end

         # Check for .git suffix
         if repo_id.end_with?(".git")
           raise ValidationError.new("repo_id", "Repository ID cannot end with '.git': '#{repo_id}'")
         end

         # Validate with regex pattern (equivalent to Python REPO_ID_REGEX)
         unless repo_id.match?(/\A(\b[\w\-.]+\b\/)?\b[\w\-.]{1,96}\b\z/)
           raise ValidationError.new("repo_id", "Repository ID must use alphanumeric chars, '-', '_' or '.'. The name cannot start or end with '-' or '.' and the maximum length is 96: '#{repo_id}'")
         end

         # Additional validation for namespace/repo format
         if repo_id.include?("/")
           namespace, name = repo_id.split("/", 2)

           if namespace.empty? || name.empty?
             raise ValidationError.new("repo_id", "Both namespace and name must be non-empty")
           end

           # Validate no leading/trailing special chars in parts
           [namespace, name].each do |part|
             if part.start_with?(".", "-", "_") || part.end_with?(".", "-", "_")
               raise ValidationError.new("repo_id", "Repository name parts cannot start or end with '.', '-', or '_'")
             end
           end
         elsif repo_id.start_with?(".", "-", "_") || repo_id.end_with?(".", "-", "_")
           raise ValidationError.new("repo_id", "Repository name cannot start or end with '.', '-', or '_'")
         end

         repo_id
       end

      # Validates a revision (branch, tag, or commit SHA).
      #
      # Valid formats:
      # - Branch names: "main", "dev", "feature/my-feature"
      # - Tags: "v1.0.0", "release-2023"
      # - Commit SHAs: 40 hexadecimal characters
      #
      # @param revision [String] Revision to validate
      # @return [String] The validated revision
      # @raise [ValidationError] If revision is invalid
      #
      # @example
      #   Validators.validate_revision("main")
      #   Validators.validate_revision("v1.0.0")
      #   Validators.validate_revision("a" * 40)  # commit SHA
      def self.validate_revision(revision)
        if revision.nil? || revision.empty?
          raise ValidationError.new("revision", "Revision cannot be empty")
        end

        # Check length (reasonable max for branch/tag names)
        if revision.length > 255
          raise ValidationError.new("revision", "Revision name is too long")
        end

        # If it looks like a commit SHA (40 hex chars), validate that
        if revision.match?(Constants::REGEX_COMMIT_OID)
          return revision
        end

        # For branch/tag names, allow alphanumeric, hyphen, underscore, dot, slash
        unless revision.match?(/\A[a-zA-Z0-9._\/-]+\z/)
          raise ValidationError.new("revision", "Revision contains invalid characters")
        end

        # Disallow leading/trailing slashes
        if revision.start_with?("/") || revision.end_with?("/")
          raise ValidationError.new("revision", "Revision cannot start or end with '/'")
        end

        revision
      end

      # Validates a filename for use in repository paths.
      #
      # Ensures filename doesn't contain path traversal sequences or
      # other potentially dangerous patterns.
      #
      # @param filename [String] Filename to validate
      # @return [String] The validated filename
      # @raise [ValidationError] If filename is unsafe
      #
      # @example Valid filenames
      #   Validators.validate_filename("config.json")
      #   Validators.validate_filename("models/pytorch_model.bin")
      #   Validators.validate_filename("data/train.csv")
      #
      # @example Invalid filenames
      #   Validators.validate_filename("../etc/passwd")  # raises
      #   Validators.validate_filename("/absolute/path")  # raises
      def self.validate_filename(filename)
        if filename.nil? || filename.empty?
          raise ValidationError.new("filename", "Filename cannot be empty")
        end

        # Disallow absolute paths
        if filename.start_with?("/")
          raise ValidationError.new("filename", "Filename cannot be an absolute path")
        end

        # Disallow path traversal
        if filename.include?("../") || filename.include?("..\\")
          raise ValidationError.new("filename", "Filename cannot contain path traversal sequences")
        end

        # Disallow null bytes
        if filename.include?("\0")
          raise ValidationError.new("filename", "Filename cannot contain null bytes")
        end

        # Disallow Windows reserved names
        basename = File.basename(filename)
        windows_reserved = %w[CON PRN AUX NUL COM1 COM2 COM3 COM4 COM5 COM6 COM7 COM8 COM9
                             LPT1 LPT2 LPT3 LPT4 LPT5 LPT6 LPT7 LPT8 LPT9]
        if windows_reserved.include?(basename.upcase)
          raise ValidationError.new("filename", "Filename cannot use Windows reserved names")
        end

        filename
      end

      # Validates a repository type.
      #
      # @param repo_type [String] Repository type
      # @return [String] The validated repo_type
      # @raise [ValidationError] If repo_type is invalid
      #
      # @example
      #   Validators.validate_repo_type("model")
      #   Validators.validate_repo_type("dataset")
      def self.validate_repo_type(repo_type)
        unless Constants::REPO_TYPES.include?(repo_type)
          valid_types = Constants::REPO_TYPES.join(", ")
          raise ValidationError.new(
            "repo_type",
            "Invalid repository type '#{repo_type}'. Must be one of: #{valid_types}"
          )
        end

        repo_type
      end

      # Validates that a value is not nil.
      #
      # @param value [Object] Value to check
      # @param name [String] Parameter name for error message
      # @return [Object] The value if not nil
      # @raise [ValidationError] If value is nil
      def self.require_non_nil(value, name)
        if value.nil?
          raise ValidationError.new(name, "#{name} is required and cannot be nil")
        end

        value
      end

      # Validates that a string is not empty.
      #
      # @param value [String] String to check
      # @param name [String] Parameter name for error message
      # @return [String] The value if not empty
      # @raise [ValidationError] If value is nil or empty
      def self.require_non_empty(value, name)
        if value.nil? || (value.respond_to?(:empty?) && value.empty?)
          raise ValidationError.new(name, "#{name} cannot be empty")
        end

        value
      end
    end
  end
end
