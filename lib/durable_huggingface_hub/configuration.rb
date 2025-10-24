# frozen_string_literal: true

require "pathname"

module DurableHuggingfaceHub
  # Configuration management for the HuggingFace Hub client.
  #
  # This class provides a singleton configuration object that can be accessed
  # and modified throughout the library. Configuration values are read from
  # environment variables or can be set programmatically.
  #
  # @example Accessing the configuration
  #   DurableHuggingfaceHub::Configuration.instance.token
  #
  # @example Configuring programmatically
  #   DurableHuggingfaceHub.configure do |config|
  #     config.token = "hf_your_token_here"
  #     config.cache_dir = "/custom/cache/path"
  #   end
  class Configuration
    # @return [String, nil] HuggingFace API token
    attr_accessor :token

    # @return [String] Base cache directory for HuggingFace Hub files
    attr_accessor :cache_dir

    # @return [String] HuggingFace Hub endpoint URL
    attr_accessor :endpoint

    # @return [Boolean] Whether to operate in offline mode
    attr_accessor :offline

    # @return [Boolean] Whether to disable progress bars during downloads
    attr_accessor :disable_progress_bars

    # @return [Boolean] Whether to disable telemetry
    attr_accessor :disable_telemetry

    # @return [Integer] Default timeout for API requests
    attr_accessor :request_timeout

    # @return [Integer] Default timeout for downloads
    attr_accessor :download_timeout

    # Creates a new Configuration instance with default values.
    #
    # Configuration values are read from environment variables if available,
    # otherwise sensible defaults are used.
    def initialize
      @token = env_var("HF_TOKEN") || env_var("HUGGING_FACE_HUB_TOKEN")
      @cache_dir = determine_cache_dir
      @endpoint = env_var("HF_ENDPOINT") || Constants::ENDPOINT
      @offline = parse_boolean(env_var("HF_HUB_OFFLINE"), default: false)
      @disable_progress_bars = parse_boolean(env_var("HF_HUB_DISABLE_PROGRESS_BARS"), default: false)
      @disable_telemetry = parse_boolean(env_var("HF_HUB_DISABLE_TELEMETRY"), default: true)
      @request_timeout = parse_integer(env_var("HF_HUB_REQUEST_TIMEOUT"),
default: Constants::DEFAULT_REQUEST_TIMEOUT)
      @download_timeout = parse_integer(env_var("HF_HUB_DOWNLOAD_TIMEOUT"),
                                        default: Constants::DEFAULT_DOWNLOAD_TIMEOUT)
    end

    # Returns the singleton configuration instance.
    #
    # @return [Configuration] The singleton configuration object
    def self.instance
      @instance ||= new
    end

    # Resets the configuration to default values.
    # Primarily used for testing.
    #
    # @return [Configuration] A new configuration instance
    def self.reset!
      @instance = new
    end

    # Returns the path to the HuggingFace Hub cache directory.
    #
    # The cache directory is created if it doesn't exist.
    #
    # @return [Pathname] Path to the HuggingFace Hub cache
    def hub_cache_dir
      path = Pathname.new(cache_dir).join(Constants::HF_CACHE_SUBDIR)
      path.mkpath unless path.exist?
      path
    end

    # Returns the path to the token file.
    #
    # @return [Pathname] Path to the token storage file
    def token_path
      Pathname.new(cache_dir).join("token")
    end

    private

    # Retrieves an environment variable value.
    #
    # @param key [String] The environment variable name
    # @return [String, nil] The environment variable value or nil if not set
    def env_var(key)
      value = ENV[key]
      value&.empty? ? nil : value
    end

    # Parses a boolean value from a string.
    #
    # Recognizes common boolean representations:
    # - true: "1", "true", "yes", "on" (case-insensitive)
    # - false: "0", "false", "no", "off" (case-insensitive)
    #
    # @param value [String, nil] The string value to parse
    # @param default [Boolean] Default value if parsing fails
    # @return [Boolean] The parsed boolean value
    def parse_boolean(value, default: false)
      return default if value.nil?

      case value.downcase.strip
      when "1", "true", "yes", "on"
        true
      when "0", "false", "no", "off"
        false
      else
        default
      end
    end

    # Parses an integer value from a string.
    #
    # @param value [String, nil] The string value to parse
    # @param default [Integer] Default value if parsing fails
    # @return [Integer] The parsed integer value
    def parse_integer(value, default:)
      return default if value.nil?

      Integer(value)
    rescue ArgumentError
      default
    end

    # Determines the cache directory from environment variables or defaults.
    #
    # Priority order:
    # 1. HF_HOME
    # 2. XDG_CACHE_HOME/huggingface
    # 3. ~/.cache/huggingface (Linux/Mac)
    # 4. ~/AppData/Local/huggingface (Windows)
    #
    # @return [String] Path to the cache directory
    def determine_cache_dir
      if (hf_home = env_var("HF_HOME"))
        return hf_home
      end

      if (xdg_cache = env_var("XDG_CACHE_HOME"))
        return Pathname.new(xdg_cache).join("huggingface").to_s
      end

      # Default cache locations by platform
      home = Dir.home
      if Gem.win_platform?
        Pathname.new(home).join("AppData", "Local", "huggingface").to_s
      else
        Pathname.new(home).join(".cache", "huggingface").to_s
      end
    end
  end

  # Provides a convenient way to configure the library.
  #
  # @example
  #   DurableHuggingfaceHub.configure do |config|
  #     config.token = "hf_your_token"
  #     config.cache_dir = "/tmp/hf_cache"
  #   end
  #
  # @yield [config] Yields the configuration object for modification
  # @yieldparam config [Configuration] The configuration object
  # @return [Configuration] The configuration object
  def self.configure
    yield(Configuration.instance) if block_given?
    Configuration.instance
  end

  # Returns the current configuration.
  #
  # @return [Configuration] The current configuration object
  def self.config
    Configuration.instance
  end
end
