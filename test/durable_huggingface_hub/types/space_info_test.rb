# frozen_string_literal: true

require "test_helper"

module DurableHuggingfaceHub
  module Types
    class SpaceInfoTest < Minitest::Test
      def full_hash
        space_info_hash
      end

      def test_creates_from_minimal_hash
        info = SpaceInfo.from_hash({ "id" => "gradio/hello-world" })
        assert_equal "gradio/hello-world", info.id
      end

      def test_creates_from_full_hash
        info = SpaceInfo.from_hash(full_hash)
        assert_equal "stabilityai/stable-diffusion", info.id
        assert_equal 10_000, info.likes
        assert_equal "stabilityai", info.author
      end

      def test_tags_default_to_empty_array
        info = SpaceInfo.from_hash({ "id" => "gradio/hello" })
        assert_equal [], info.tags
      end

      def test_sdk_attribute
        info = SpaceInfo.from_hash(full_hash.merge("sdk" => "gradio"))
        assert_equal "gradio", info.sdk
      end

      def test_runtime_attribute
        info = SpaceInfo.from_hash(full_hash.merge("runtime" => { "stage" => "RUNNING" }))
        assert_equal({ "stage" => "RUNNING" }, info.runtime)
      end

      def test_runtime_stage
        info = SpaceInfo.from_hash(full_hash.merge("runtime" => { "stage" => "RUNNING" }))
        assert_equal "RUNNING", info.runtime_stage
      end

      def test_runtime_stage_nil_when_no_runtime
        info = SpaceInfo.from_hash(full_hash)
        assert_nil info.runtime_stage
      end

      def test_running_true_when_stage_running
        info = SpaceInfo.from_hash(full_hash.merge("runtime" => { "stage" => "RUNNING" }))
        assert info.running?
      end

      def test_running_false_when_stage_stopped
        info = SpaceInfo.from_hash(full_hash.merge("runtime" => { "stage" => "STOPPED" }))
        refute info.running?
      end

      def test_running_false_when_no_runtime
        info = SpaceInfo.from_hash(full_hash)
        refute info.running?
      end

      def test_public_when_not_private
        info = SpaceInfo.from_hash(full_hash)
        assert info.public?
      end

      def test_not_public_when_private
        info = SpaceInfo.from_hash(full_hash.merge("private" => true))
        refute info.public?
      end

      def test_has_tag_true
        info = SpaceInfo.from_hash(full_hash)
        assert info.has_tag?("stable-diffusion")
      end

      def test_to_s_includes_id
        info = SpaceInfo.from_hash(full_hash.merge("sdk" => "gradio"))
        to_str = info.to_s
        assert_includes to_str, "stabilityai/stable-diffusion"
        assert_includes to_str, "gradio"
      end

      def test_inspect_includes_id
        info = SpaceInfo.from_hash(full_hash)
        assert_includes info.inspect, "stabilityai/stable-diffusion"
      end
    end
  end
end
