# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module DurableHuggingfaceHub
  module Utils
    class AuthTest < Minitest::Test
      def setup
        @original_hf_token = ENV["HF_TOKEN"]
        @original_hf_hub_token = ENV["HUGGING_FACE_HUB_TOKEN"]
        ENV.delete("HF_TOKEN")
        ENV.delete("HUGGING_FACE_HUB_TOKEN")

        @tmpdir = Dir.mktmpdir
        DurableHuggingfaceHub::Configuration.reset!
        DurableHuggingfaceHub.configure { |c| c.cache_dir = @tmpdir }
      end

      def teardown
        ENV["HF_TOKEN"] = @original_hf_token if @original_hf_token
        ENV["HUGGING_FACE_HUB_TOKEN"] = @original_hf_hub_token if @original_hf_hub_token
        FileUtils.rm_rf(@tmpdir)
        DurableHuggingfaceHub::Configuration.reset!
      end

      # --- get_token ---

      def test_returns_explicit_token_when_provided
        assert_equal "hf_explicit_token", Auth.get_token(token: "hf_explicit_token")
      end

      def test_returns_hf_token_env_var
        ENV["HF_TOKEN"] = "hf_env_token"
        assert_equal "hf_env_token", Auth.get_token
      end

      def test_returns_legacy_env_var_when_hf_token_absent
        ENV["HUGGING_FACE_HUB_TOKEN"] = "hf_legacy_token"
        assert_equal "hf_legacy_token", Auth.get_token
      end

      def test_prefers_hf_token_over_legacy
        ENV["HF_TOKEN"] = "hf_primary"
        ENV["HUGGING_FACE_HUB_TOKEN"] = "hf_legacy"
        assert_equal "hf_primary", Auth.get_token
      end

      def test_returns_nil_when_no_token_available
        assert_nil Auth.get_token
      end

      def test_ignores_empty_explicit_token
        ENV["HF_TOKEN"] = "hf_env_token"
        assert_equal "hf_env_token", Auth.get_token(token: "")
      end

      def test_reads_token_from_file
        token_path = DurableHuggingfaceHub::Configuration.instance.token_path
        FileUtils.mkdir_p(token_path.dirname)
        File.write(token_path, "hf_file_token")
        assert_equal "hf_file_token", Auth.get_token
      end

      def test_strips_whitespace_from_file_token
        token_path = DurableHuggingfaceHub::Configuration.instance.token_path
        FileUtils.mkdir_p(token_path.dirname)
        File.write(token_path, "  hf_file_token\n  ")
        assert_equal "hf_file_token", Auth.get_token
      end

      # --- write_token_to_file / read_token_from_file ---

      def test_write_and_read_token
        Auth.write_token_to_file("hf_written_token")
        assert_equal "hf_written_token", Auth.read_token_from_file
      end

      def test_write_sets_restrictive_permissions
        Auth.write_token_to_file("hf_token_perms")
        token_path = DurableHuggingfaceHub::Configuration.instance.token_path
        mode = File.stat(token_path).mode & 0o777
        assert_equal 0o600, mode
      end

      def test_read_returns_nil_when_file_absent
        assert_nil Auth.read_token_from_file
      end

      # --- delete_token_file ---

      def test_delete_token_file_returns_true_when_exists
        Auth.write_token_to_file("hf_delete_me")
        assert Auth.delete_token_file
      end

      def test_delete_token_file_returns_false_when_absent
        refute Auth.delete_token_file
      end

      def test_delete_removes_file
        Auth.write_token_to_file("hf_to_delete")
        Auth.delete_token_file
        assert_nil Auth.read_token_from_file
      end

      # --- valid_token_format? ---

      def test_valid_token_format_with_hf_prefix
        assert Auth.valid_token_format?("hf_abcdefghijklm")
      end

      def test_invalid_token_format_without_prefix
        refute Auth.valid_token_format?("abc123")
      end

      def test_invalid_token_format_too_short
        refute Auth.valid_token_format?("hf_short")
      end

      def test_invalid_token_format_nil
        refute Auth.valid_token_format?(nil)
      end

      def test_invalid_token_format_empty
        refute Auth.valid_token_format?("")
      end

      def test_valid_token_format_with_underscores_and_dashes
        assert Auth.valid_token_format?("hf_abc-def_ghi123")
      end

      # --- get_token! ---

      def test_get_token_bang_returns_token_when_available
        ENV["HF_TOKEN"] = "hf_available"
        assert_equal "hf_available", Auth.get_token!
      end

      def test_get_token_bang_raises_when_no_token
        assert_raises(LocalTokenNotFoundError) { Auth.get_token! }
      end

      # --- mask_token ---

      def test_mask_token_hides_middle
        masked = Auth.mask_token("hf_abc123def456ghi789")
        assert masked.include?("hf_abc1")
        assert masked.include?("...")
        refute masked.include?("def456")
      end

      def test_mask_token_handles_empty
        assert_equal "", Auth.mask_token("")
      end

      def test_mask_token_handles_nil
        assert_equal "", Auth.mask_token(nil)
      end

      def test_mask_token_short_token_returned_as_is
        assert_equal "hf_abc", Auth.mask_token("hf_abc")
      end
    end
  end
end
