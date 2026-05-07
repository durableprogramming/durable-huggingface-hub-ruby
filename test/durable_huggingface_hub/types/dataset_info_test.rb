# frozen_string_literal: true

require "test_helper"

module DurableHuggingfaceHub
  module Types
    class DatasetInfoTest < Minitest::Test
      def full_hash
        dataset_info_hash
      end

      def test_creates_from_minimal_hash
        info = DatasetInfo.from_hash({ "id" => "squad" })
        assert_equal "squad", info.id
      end

      def test_creates_from_full_hash
        info = DatasetInfo.from_hash(full_hash)
        assert_equal "squad", info.id
        assert_equal 500_000, info.downloads
        assert_equal 200, info.likes
        assert_equal "rajpurkar", info.author
      end

      def test_tags_default_to_empty_array
        info = DatasetInfo.from_hash({ "id" => "squad" })
        assert_equal [], info.tags
      end

      def test_tags_from_hash
        info = DatasetInfo.from_hash(full_hash)
        assert_includes info.tags, "question-answering"
      end

      def test_file_names_from_siblings
        info = DatasetInfo.from_hash(full_hash)
        assert_includes info.file_names, "README.md"
        assert_includes info.file_names, "dataset_infos.json"
      end

      def test_file_names_empty_when_no_siblings
        info = DatasetInfo.from_hash({ "id" => "squad" })
        assert_equal [], info.file_names
      end

      def test_public_when_not_private
        info = DatasetInfo.from_hash(full_hash)
        assert info.public?
      end

      def test_not_public_when_private
        info = DatasetInfo.from_hash(full_hash.merge("private" => true))
        refute info.public?
      end

      def test_has_tag_true
        info = DatasetInfo.from_hash(full_hash)
        assert info.has_tag?("question-answering")
      end

      def test_has_tag_false
        info = DatasetInfo.from_hash(full_hash)
        refute info.has_tag?("nonexistent")
      end

      def test_gated_false_by_default
        info = DatasetInfo.from_hash({ "id" => "squad" })
        refute info.gated?
      end

      def test_gated_true_when_auto
        info = DatasetInfo.from_hash(full_hash.merge("gated" => "auto"))
        assert info.gated?
      end

      def test_disabled_false_by_default
        info = DatasetInfo.from_hash({ "id" => "squad" })
        refute info.disabled?
      end

      def test_to_s_returns_id
        info = DatasetInfo.from_hash(full_hash)
        assert_equal "squad", info.to_s
      end

      def test_inspect_includes_id
        info = DatasetInfo.from_hash(full_hash)
        assert_includes info.inspect, "squad"
      end

      def test_ignores_unknown_keys
        info = DatasetInfo.from_hash(full_hash.merge("unknownField" => "value"))
        assert_equal "squad", info.id
      end

      def test_description_attribute
        info = DatasetInfo.from_hash(full_hash.merge("description" => "Question answering dataset"))
        assert_equal "Question answering dataset", info.description
      end
    end
  end
end
