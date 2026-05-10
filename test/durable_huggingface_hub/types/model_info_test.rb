# frozen_string_literal: true

require "test_helper"

module DurableHuggingfaceHub
  module Types
    class ModelInfoTest < Minitest::Test
      def minimal_hash
        { "id" => "bert-base-uncased" }
      end

      def full_hash
        model_info_hash
      end

      def test_creates_from_minimal_hash
        info = ModelInfo.from_hash(minimal_hash)

        assert_equal "bert-base-uncased", info.id
      end

      def test_creates_from_full_hash
        info = ModelInfo.from_hash(full_hash)

        assert_equal "bert-base-uncased", info.id
        assert_equal 1_000_000, info.downloads
        assert_equal 500, info.likes
        assert_equal "transformers", info.library_name
        assert_equal "google", info.author
      end

      def test_tags_default_to_empty_array
        info = ModelInfo.from_hash(minimal_hash)

        assert_empty info.tags
      end

      def test_tags_from_hash
        info = ModelInfo.from_hash(full_hash)

        assert_includes info.tags, "transformers"
        assert_includes info.tags, "pytorch"
      end

      def test_pipeline_tag
        info = ModelInfo.from_hash(full_hash)

        assert_equal "fill-mask", info.pipeline_tag
      end

      def test_sha
        info = ModelInfo.from_hash(full_hash)

        assert_equal "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", info.sha
      end

      def test_siblings_file_names
        info = ModelInfo.from_hash(full_hash)
        names = info.file_names

        assert_includes names, "config.json"
        assert_includes names, "pytorch_model.bin"
      end

      def test_file_names_empty_when_no_siblings
        info = ModelInfo.from_hash(minimal_hash)

        assert_empty info.file_names
      end

      def test_public_when_not_private
        info = ModelInfo.from_hash(full_hash.merge("private" => false))

        assert_predicate info, :public?
      end

      def test_not_public_when_private
        info = ModelInfo.from_hash(full_hash.merge("private" => true))

        refute_predicate info, :public?
      end

      def test_has_tag_true
        info = ModelInfo.from_hash(full_hash)

        assert info.has_tag?("pytorch")
      end

      def test_has_tag_false
        info = ModelInfo.from_hash(full_hash)

        refute info.has_tag?("nonexistent")
      end

      def test_gated_false_when_not_gated
        info = ModelInfo.from_hash(full_hash)

        refute_predicate info, :gated?
      end

      def test_gated_true_when_auto
        info = ModelInfo.from_hash(full_hash.merge("gated" => "auto"))

        assert_predicate info, :gated?
      end

      def test_gated_true_when_manual
        info = ModelInfo.from_hash(full_hash.merge("gated" => "manual"))

        assert_predicate info, :gated?
      end

      def test_disabled_false_by_default
        info = ModelInfo.from_hash(minimal_hash)

        refute_predicate info, :disabled?
      end

      def test_disabled_true_when_set
        info = ModelInfo.from_hash(full_hash.merge("disabled" => true))

        assert_predicate info, :disabled?
      end

      def test_to_s_includes_id
        info = ModelInfo.from_hash(full_hash)

        assert_includes info.to_s, "bert-base-uncased"
      end

      def test_to_s_includes_pipeline_tag
        info = ModelInfo.from_hash(full_hash)

        assert_includes info.to_s, "fill-mask"
      end

      def test_inspect_includes_id
        info = ModelInfo.from_hash(full_hash)

        assert_includes info.inspect, "bert-base-uncased"
      end

      def test_camel_case_keys_transformed
        info = ModelInfo.from_hash({
          "id" => "test/model",
          "lastModified" => "2023-01-01T00:00:00.000Z",
          "createdAt" => "2022-01-01T00:00:00.000Z",
          "pipelineTag" => "text-classification",
          "libraryName" => "transformers"
        })

        assert_equal "text-classification", info.pipeline_tag
        assert_equal "transformers", info.library_name
      end
    end
  end
end
