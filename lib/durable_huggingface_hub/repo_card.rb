# frozen_string_literal: true

require "yaml"
require "pathname"
require_relative "hf_api"
require_relative "utils/validators"

module DurableHuggingfaceHub
  # Base class for repository cards (README.md files with YAML frontmatter).
  #
  # Repository cards contain metadata and documentation for models, datasets,
  # and spaces on the HuggingFace Hub. They consist of YAML frontmatter
  # followed by markdown content.
  #
  # @example Load a model card from the Hub
  #   card = DurableHuggingfaceHub::ModelCard.load("bert-base-uncased")
  #   puts card.data["license"]
  #   puts card.text
  #
  # @example Create and save a new model card
  #   card = DurableHuggingfaceHub::ModelCard.new(
  #     text: "# My Model\n\nThis is my model.",
  #     data: { "license" => "mit", "language" => "en" }
  #   )
  #   card.save("my-model/README.md")
  class RepoCard
    # @return [Hash] Metadata from YAML frontmatter
    attr_accessor :data

    # @return [String] Markdown content (without frontmatter)
    attr_accessor :text

    # Initialize a new RepoCard
    #
    # @param text [String] Markdown content
    # @param data [Hash] Metadata dictionary
    def initialize(text: "", data: {})
      @text = text || ""
      @data = data || {}
    end

    # Load a repository card from a file.
    #
    # @param file_path [String, Pathname] Path to the README.md file
    # @return [RepoCard] The loaded repository card
    #
    # @example Load from local file
    #   card = RepoCard.load("path/to/README.md")
    def self.load(file_path)
      file_path = Pathname(file_path)
      raise ArgumentError, "File not found: #{file_path}" unless file_path.exist?

      content = file_path.read
      parse(content)
    end

    # Load a repository card from the HuggingFace Hub.
    #
    # @param repo_id [String] Repository ID
    # @param repo_type [String, Symbol] Type of repository ("model", "dataset", or "space")
    # @param revision [String, nil] Git revision (branch, tag, or commit SHA)
    # @param token [String, nil] HuggingFace API token
    # @param timeout [Numeric, nil] Request timeout in seconds
    # @return [RepoCard] The loaded repository card
    #
    # @raise [RepositoryNotFoundError] If repository doesn't exist
    # @raise [EntryNotFoundError] If README.md doesn't exist
    #
    # @example Load model card from Hub
    #   card = ModelCard.from_hub("bert-base-uncased")
    def self.from_hub(repo_id, repo_type: nil, revision: nil, token: nil, timeout: nil)
      Utils::Validators.validate_repo_id(repo_id)
      repo_type ||= self.default_repo_type
      repo_type = Utils::Validators.validate_repo_type(repo_type)

      api = HfApi.new(token: token)

      # Build URL for README.md
      url_path = "/#{repo_type}s/#{repo_id}/resolve/#{revision || 'main'}/README.md"

      begin
        response = api.http_client.get(url_path, timeout: timeout)
        content = response.body
        parse(content)
      rescue HfHubHTTPError => e
        if e.status_code == 404
          raise EntryNotFoundError, "README.md not found in #{repo_id}"
        else
          raise
        end
      end
    end

    # Parse repository card content (YAML frontmatter + markdown).
    #
    # @param content [String] Full content of README.md
    # @return [RepoCard] Parsed repository card
    #
    # @example Parse content string
    #   content = "---\nlicense: mit\n---\n# My Model"
    #   card = RepoCard.parse(content)
    def self.parse(content)
      # Check for YAML frontmatter (starts with ---)
      if content.start_with?("---\n")
        # Find the closing ---
        end_index = content.index("\n---\n", 4)

        if end_index
          # Extract YAML frontmatter
          yaml_content = content[4...end_index]
          markdown_content = content[(end_index + 5)..-1] || ""

          begin
            metadata = YAML.safe_load(yaml_content, permitted_classes: [Date, Time]) || {}
          rescue Psych::SyntaxError => e
            warn "Failed to parse YAML frontmatter: #{e.message}"
            metadata = {}
          end

          new(text: markdown_content.strip, data: metadata)
        else
          # No closing ---, treat everything as content
          new(text: content)
        end
      else
        # No frontmatter
        new(text: content)
      end
    end

    # Convert the repository card to a string (YAML frontmatter + markdown).
    #
    # @return [String] Full content with frontmatter
    #
    # @example Convert to string
    #   content = card.to_s
    #   File.write("README.md", content)
    def to_s
      if @data.empty?
        @text
      else
        yaml_str = YAML.dump(@data).sub(/^---\n/, "")
        "---\n#{yaml_str}---\n\n#{@text}"
      end
    end

    # Save the repository card to a file.
    #
    # @param file_path [String, Pathname] Path to save the README.md file
    #
    # @example Save to local file
    #   card.save("my-model/README.md")
    def save(file_path)
      file_path = Pathname(file_path)
      file_path.dirname.mkpath # Create parent directories if needed
      file_path.write(to_s)
    end

    # Push the repository card to the HuggingFace Hub.
    #
    # @param repo_id [String] Repository ID
    # @param repo_type [String, Symbol] Type of repository
    # @param revision [String, nil] Git revision to push to
    # @param commit_message [String, nil] Commit message
    # @param commit_description [String, nil] Commit description
    # @param token [String, nil] HuggingFace API token
    # @param timeout [Numeric, nil] Request timeout in seconds
    # @return [String] URL of the uploaded README.md
    #
    # @example Push to Hub
    #   card.push_to_hub("my-username/my-model")
    def push_to_hub(
      repo_id,
      repo_type: self.class.default_repo_type,
      revision: nil,
      commit_message: nil,
      commit_description: nil,
      token: nil,
      timeout: nil
    )
      api = HfApi.new(token: token)

      # Create a temporary file with the content
      require "tempfile"
      Tempfile.create(["README", ".md"]) do |temp_file|
        temp_file.write(to_s)
        temp_file.flush

        api.upload_file(
          repo_id: repo_id,
          path_or_fileobj: temp_file.path,
          path_in_repo: "README.md",
          repo_type: repo_type,
          revision: revision,
          commit_message: commit_message || "Update README.md",
          commit_description: commit_description,
          timeout: timeout
        )
      end
    end

    # Update the metadata in the repository card.
    #
    # @param updates [Hash] Metadata updates to merge
    #
    # @example Update metadata
    #   card.update_metadata({ "license" => "apache-2.0" })
    def update_metadata(updates)
      @data.merge!(updates)
    end

    # Default repository type for this card class.
    # Subclasses should override this.
    #
    # @return [String] Default repository type
    def self.default_repo_type
      "model"
    end

    # Validate the repository card metadata.
    # Subclasses can override this to add specific validation.
    #
    # @return [Array<String>] List of validation errors (empty if valid)
    def validate
      []
    end
  end

  # Model card for documenting machine learning models.
  #
  # Model cards provide essential information about models including:
  # - Model architecture and training details
  # - Intended use and limitations
  # - Training data and evaluation results
  # - Ethical considerations
  #
  # @example Create a model card
  #   card = ModelCard.new(
  #     text: "# BERT Base Uncased\n\nBERT model trained on...",
  #     data: {
  #       "license" => "apache-2.0",
  #       "language" => "en",
  #       "tags" => ["bert", "nlp"]
  #     }
  #   )
  class ModelCard < RepoCard
    # @return [String] Default repository type for model cards
    def self.default_repo_type
      "model"
    end

    # Validate model card metadata.
    #
    # @return [Array<String>] List of validation errors
    def validate
      errors = []

      # Check for required fields
      errors << "license is required" unless @data["license"]
      errors << "language is required" unless @data["language"]

      # Validate license format (should be SPDX identifier)
      if @data["license"] && !@data["license"].is_a?(String)
        errors << "license must be a string"
      end

      # Validate language format
      if @data["language"]
        if @data["language"].is_a?(String)
          # Single language
        elsif @data["language"].is_a?(Array)
          # Multiple languages
          @data["language"].each do |lang|
            errors << "language array elements must be strings" unless lang.is_a?(String)
          end
        else
          errors << "language must be a string or array of strings"
        end
      end

      # Validate tags format
      if @data["tags"] && !@data["tags"].is_a?(Array)
        errors << "tags must be an array"
      end

      errors
    end

    # Add evaluation results to the model card metadata.
    #
    # @param task_type [String] Type of task (e.g., "text-classification")
    # @param dataset_name [String] Name of the evaluation dataset
    # @param metric_name [String] Name of the metric
    # @param metric_value [Numeric] Value of the metric
    #
    # @example Add evaluation result
    #   card.add_evaluation_result(
    #     task_type: "text-classification",
    #     dataset_name: "glue",
    #     metric_name: "accuracy",
    #     metric_value: 0.95
    #   )
    def add_evaluation_result(task_type:, dataset_name:, metric_name:, metric_value:)
      @data["model-index"] ||= []

      model_index = @data["model-index"].first || {}
      model_index["results"] ||= []

      result = {
        "task" => { "type" => task_type },
        "dataset" => { "name" => dataset_name },
        "metrics" => [{ "name" => metric_name, "value" => metric_value }]
      }

      model_index["results"] << result
      @data["model-index"] = [model_index] if @data["model-index"].empty?
    end
  end

  # Dataset card for documenting datasets.
  #
  # Dataset cards provide information about datasets including:
  # - Dataset description and structure
  # - Data collection methodology
  # - Intended use cases
  # - Limitations and biases
  #
  # @example Create a dataset card
  #   card = DatasetCard.new(
  #     text: "# My Dataset\n\nThis dataset contains...",
  #     data: {
  #       "license" => "cc-by-4.0",
  #       "language" => ["en", "es"],
  #       "task_categories" => ["text-classification"]
  #     }
  #   )
  class DatasetCard < RepoCard
    # @return [String] Default repository type for dataset cards
    def self.default_repo_type
      "dataset"
    end

    # Validate dataset card metadata.
    #
    # @return [Array<String>] List of validation errors
    def validate
      errors = []

      # Check for required fields
      errors << "license is required" unless @data["license"]

      # Validate license format
      if @data["license"] && !@data["license"].is_a?(String)
        errors << "license must be a string"
      end

      # Validate language format
      if @data["language"]
        if @data["language"].is_a?(String)
          # Single language
        elsif @data["language"].is_a?(Array)
          # Multiple languages
          @data["language"].each do |lang|
            errors << "language array elements must be strings" unless lang.is_a?(String)
          end
        else
          errors << "language must be a string or array of strings"
        end
      end

      # Validate task_categories format
      if @data["task_categories"] && !@data["task_categories"].is_a?(Array)
        errors << "task_categories must be an array"
      end

      errors
    end
  end

  # Space card for documenting Spaces (interactive demos).
  #
  # Space cards provide information about Gradio/Streamlit apps including:
  # - App description and usage
  # - Technical requirements
  # - Model dependencies
  #
  # @example Create a space card
  #   card = SpaceCard.new(
  #     text: "# My Demo\n\nThis space demonstrates...",
  #     data: {
  #       "sdk" => "gradio",
  #       "sdk_version" => "3.0.0",
  #       "app_file" => "app.py"
  #     }
  #   )
  class SpaceCard < RepoCard
    # @return [String] Default repository type for space cards
    def self.default_repo_type
      "space"
    end

    # Validate space card metadata.
    #
    # @return [Array<String>] List of validation errors
    def validate
      errors = []

      # Check for required fields
      errors << "sdk is required" unless @data["sdk"]
      errors << "app_file is required" unless @data["app_file"]

      # Validate SDK
      if @data["sdk"] && !["gradio", "streamlit", "docker", "static"].include?(@data["sdk"])
        errors << "sdk must be one of: gradio, streamlit, docker, static"
      end

      # Validate app_file
      if @data["app_file"] && !@data["app_file"].is_a?(String)
        errors << "app_file must be a string"
      end

      # Validate sdk_version format
      if @data["sdk_version"] && !@data["sdk_version"].is_a?(String)
        errors << "sdk_version must be a string"
      end

      errors
    end
  end
end
