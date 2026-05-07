# frozen_string_literal: true

require "test_helper"

module DurableHuggingfaceHub
  module Utils
    class ValidatorsTest < Minitest::Test
      # --- validate_repo_id ---

      def test_valid_simple_repo_id
        assert_equal "bert-base-uncased", Validators.validate_repo_id("bert-base-uncased")
      end

      def test_valid_namespaced_repo_id
        assert_equal "google/bert-base-uncased", Validators.validate_repo_id("google/bert-base-uncased")
      end

      def test_valid_repo_id_with_dots
        assert_equal "my-org/my.model-v2", Validators.validate_repo_id("my-org/my.model-v2")
      end

      def test_valid_repo_id_with_underscores
        assert_equal "my_model", Validators.validate_repo_id("my_model")
      end

      def test_valid_repo_id_with_numbers
        assert_equal "model123", Validators.validate_repo_id("model123")
      end

      def test_raises_on_nil_repo_id
        assert_raises(ValidationError) { Validators.validate_repo_id(nil) }
      end

      def test_raises_on_empty_repo_id
        assert_raises(ValidationError) { Validators.validate_repo_id("") }
      end

      def test_raises_on_non_string_repo_id
        assert_raises(ValidationError) { Validators.validate_repo_id(123) }
      end

      def test_raises_on_too_long_repo_id
        assert_raises(ValidationError) { Validators.validate_repo_id("a" * 97) }
      end

      def test_raises_on_multiple_slashes
        assert_raises(ValidationError) { Validators.validate_repo_id("org/repo/sub") }
      end

      def test_raises_on_double_dash
        assert_raises(ValidationError) { Validators.validate_repo_id("foo--bar") }
      end

      def test_raises_on_double_dot
        assert_raises(ValidationError) { Validators.validate_repo_id("foo..bar") }
      end

      def test_raises_on_git_suffix
        assert_raises(ValidationError) { Validators.validate_repo_id("foo.git") }
      end

      def test_raises_on_leading_dot
        assert_raises(ValidationError) { Validators.validate_repo_id(".foo") }
      end

      def test_raises_on_trailing_dash
        assert_raises(ValidationError) { Validators.validate_repo_id("foo-") }
      end

      def test_raises_on_leading_dash_in_namespace
        assert_raises(ValidationError) { Validators.validate_repo_id("-org/repo") }
      end

      def test_raises_on_trailing_dot_in_name
        assert_raises(ValidationError) { Validators.validate_repo_id("org/repo.") }
      end

      # --- validate_revision ---

      def test_valid_revision_main
        assert_equal "main", Validators.validate_revision("main")
      end

      def test_valid_revision_tag
        assert_equal "v1.0.0", Validators.validate_revision("v1.0.0")
      end

      def test_valid_revision_commit_sha
        sha = "a" * 40
        assert_equal sha, Validators.validate_revision(sha)
      end

      def test_valid_revision_branch_with_slash
        assert_equal "feature/my-branch", Validators.validate_revision("feature/my-branch")
      end

      def test_raises_on_nil_revision
        assert_raises(ValidationError) { Validators.validate_revision(nil) }
      end

      def test_raises_on_empty_revision
        assert_raises(ValidationError) { Validators.validate_revision("") }
      end

      def test_raises_on_too_long_revision
        assert_raises(ValidationError) { Validators.validate_revision("a" * 256) }
      end

      def test_raises_on_revision_with_invalid_chars
        assert_raises(ValidationError) { Validators.validate_revision("rev!@#invalid") }
      end

      def test_raises_on_revision_with_leading_slash
        assert_raises(ValidationError) { Validators.validate_revision("/main") }
      end

      def test_raises_on_revision_with_trailing_slash
        assert_raises(ValidationError) { Validators.validate_revision("main/") }
      end

      # --- validate_filename ---

      def test_valid_filename
        assert_equal "config.json", Validators.validate_filename("config.json")
      end

      def test_valid_filename_with_path
        assert_equal "models/weights.bin", Validators.validate_filename("models/weights.bin")
      end

      def test_raises_on_nil_filename
        assert_raises(ValidationError) { Validators.validate_filename(nil) }
      end

      def test_raises_on_empty_filename
        assert_raises(ValidationError) { Validators.validate_filename("") }
      end

      def test_raises_on_absolute_path
        assert_raises(ValidationError) { Validators.validate_filename("/absolute/path") }
      end

      def test_raises_on_path_traversal_unix
        assert_raises(ValidationError) { Validators.validate_filename("../etc/passwd") }
      end

      def test_raises_on_path_traversal_windows
        assert_raises(ValidationError) { Validators.validate_filename("..\\windows\\system32") }
      end

      def test_raises_on_null_byte
        assert_raises(ValidationError) { Validators.validate_filename("file\0name") }
      end

      def test_raises_on_windows_reserved_name_nul
        assert_raises(ValidationError) { Validators.validate_filename("NUL") }
      end

      def test_raises_on_windows_reserved_name_con
        assert_raises(ValidationError) { Validators.validate_filename("CON") }
      end

      def test_raises_on_windows_reserved_lowercase
        assert_raises(ValidationError) { Validators.validate_filename("con") }
      end

      # --- validate_repo_type ---

      def test_valid_repo_type_model
        assert_equal "model", Validators.validate_repo_type("model")
      end

      def test_valid_repo_type_dataset
        assert_equal "dataset", Validators.validate_repo_type("dataset")
      end

      def test_valid_repo_type_space
        assert_equal "space", Validators.validate_repo_type("space")
      end

      def test_raises_on_invalid_repo_type
        assert_raises(ValidationError) { Validators.validate_repo_type("invalid") }
      end

      def test_nil_repo_type_is_valid
        # nil is included in REPO_TYPES (represents unspecified type)
        assert_nil Validators.validate_repo_type(nil)
      end

      # --- require_non_nil ---

      def test_require_non_nil_passes_non_nil_value
        assert_equal "value", Validators.require_non_nil("value", "field")
      end

      def test_require_non_nil_raises_on_nil
        assert_raises(ValidationError) { Validators.require_non_nil(nil, "field") }
      end

      def test_require_non_nil_passes_zero
        assert_equal 0, Validators.require_non_nil(0, "count")
      end

      def test_require_non_nil_passes_false
        assert_equal false, Validators.require_non_nil(false, "flag")
      end

      # --- require_non_empty ---

      def test_require_non_empty_passes_non_empty_string
        assert_equal "hello", Validators.require_non_empty("hello", "field")
      end

      def test_require_non_empty_raises_on_empty_string
        assert_raises(ValidationError) { Validators.require_non_empty("", "field") }
      end

      def test_require_non_empty_raises_on_nil
        assert_raises(ValidationError) { Validators.require_non_empty(nil, "field") }
      end
    end
  end
end
