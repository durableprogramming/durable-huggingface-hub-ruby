# frozen_string_literal: true

require "test_helper"

module DurableHuggingfaceHub
  class ConfigurationTest < Minitest::Test
    def setup
      @original_env = %w[
        HF_TOKEN HUGGING_FACE_HUB_TOKEN HF_ENDPOINT
        HF_HOME XDG_CACHE_HOME HF_HUB_OFFLINE
        HF_HUB_DISABLE_PROGRESS_BARS HF_HUB_DISABLE_TELEMETRY
        HF_HUB_REQUEST_TIMEOUT HF_HUB_DOWNLOAD_TIMEOUT
      ].to_h { |k| [k, ENV.fetch(k, nil)] }

      @original_env.each_key { |k| ENV.delete(k) }
      Configuration.reset!
    end

    def teardown
      @original_env.each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
      Configuration.reset!
    end

    def test_singleton_returns_same_instance
      a = Configuration.instance
      b = Configuration.instance

      assert_same a, b
    end

    def test_reset_returns_new_instance
      a = Configuration.instance
      Configuration.reset!
      b = Configuration.instance

      refute_same a, b
    end

    def test_default_endpoint
      assert_equal Constants::ENDPOINT, Configuration.instance.endpoint
    end

    def test_endpoint_from_env
      ENV["HF_ENDPOINT"] = "https://custom.hub.example.com"
      Configuration.reset!

      assert_equal "https://custom.hub.example.com", Configuration.instance.endpoint
    end

    def test_token_from_env
      ENV["HF_TOKEN"] = "hf_config_test_token"
      Configuration.reset!

      assert_equal "hf_config_test_token", Configuration.instance.token
    end

    def test_token_from_legacy_env
      ENV["HUGGING_FACE_HUB_TOKEN"] = "hf_legacy_config_token"
      Configuration.reset!

      assert_equal "hf_legacy_config_token", Configuration.instance.token
    end

    def test_offline_default_false
      refute Configuration.instance.offline
    end

    def test_offline_from_env_true
      ENV["HF_HUB_OFFLINE"] = "1"
      Configuration.reset!

      assert Configuration.instance.offline
    end

    def test_offline_from_env_false_string
      ENV["HF_HUB_OFFLINE"] = "false"
      Configuration.reset!

      refute Configuration.instance.offline
    end

    def test_disable_progress_bars_default_false
      refute Configuration.instance.disable_progress_bars
    end

    def test_disable_progress_bars_from_env
      ENV["HF_HUB_DISABLE_PROGRESS_BARS"] = "1"
      Configuration.reset!

      assert Configuration.instance.disable_progress_bars
    end

    def test_disable_telemetry_default_true
      assert Configuration.instance.disable_telemetry
    end

    def test_request_timeout_from_env
      ENV["HF_HUB_REQUEST_TIMEOUT"] = "60"
      Configuration.reset!

      assert_equal 60, Configuration.instance.request_timeout
    end

    def test_request_timeout_invalid_env_uses_default
      ENV["HF_HUB_REQUEST_TIMEOUT"] = "not_a_number"
      Configuration.reset!

      assert_equal Constants::DEFAULT_REQUEST_TIMEOUT, Configuration.instance.request_timeout
    end

    def test_download_timeout_from_env
      ENV["HF_HUB_DOWNLOAD_TIMEOUT"] = "120"
      Configuration.reset!

      assert_equal 120, Configuration.instance.download_timeout
    end

    def test_cache_dir_from_hf_home
      ENV["HF_HOME"] = "/custom/hf/home"
      Configuration.reset!

      assert_equal "/custom/hf/home", Configuration.instance.cache_dir
    end

    def test_cache_dir_from_xdg
      ENV["XDG_CACHE_HOME"] = "/custom/xdg"
      Configuration.reset!

      assert_equal "/custom/xdg/huggingface", Configuration.instance.cache_dir
    end

    def test_programmatic_configure
      DurableHuggingfaceHub.configure do |c|
        c.token = "hf_programmatic"
        c.endpoint = "https://test.example.com"
      end

      assert_equal "hf_programmatic", Configuration.instance.token
      assert_equal "https://test.example.com", Configuration.instance.endpoint
    end

    def test_config_accessor
      assert_same Configuration.instance, DurableHuggingfaceHub.config
    end

    def test_token_path_under_cache_dir
      DurableHuggingfaceHub.configure { |c| c.cache_dir = "/tmp/test_hf_cache" }

      assert_equal Pathname.new("/tmp/test_hf_cache/token"), Configuration.instance.token_path
    end
  end
end
