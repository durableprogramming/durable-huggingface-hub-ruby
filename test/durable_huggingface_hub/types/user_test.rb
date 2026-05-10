# frozen_string_literal: true

require "test_helper"

module DurableHuggingfaceHub
  module Types
    class UserTest < Minitest::Test
      def full_hash
        user_hash
      end

      def test_creates_from_hash
        user = User.from_hash(full_hash)

        assert_equal "test-user", user.name
      end

      def test_fullname_attribute
        user = User.from_hash(full_hash)

        assert_equal "Test User", user.fullname
      end

      def test_email_attribute
        user = User.from_hash(full_hash)

        assert_equal "test@example.com", user.email
      end

      def test_is_pro_from_is_pro_key
        user = User.from_hash(full_hash.merge("isPro" => true))

        assert_predicate user, :pro?
      end

      def test_not_pro_by_default
        user = User.from_hash(full_hash)

        refute_predicate user, :pro?
      end

      def test_display_name_uses_fullname_when_available
        user = User.from_hash(full_hash)

        assert_equal "Test User", user.display_name
      end

      def test_display_name_falls_back_to_name
        user = User.from_hash({ "name" => "test-user" })

        assert_equal "test-user", user.display_name
      end

      def test_to_s_returns_display_name
        user = User.from_hash(full_hash)

        assert_equal "Test User", user.to_s
      end

      def test_inspect_includes_name
        user = User.from_hash(full_hash)

        assert_includes user.inspect, "test-user"
      end

      def test_avatar_url_camelcase_transform
        user = User.from_hash(full_hash.merge("avatarUrl" => "https://example.com/avatar.jpg"))

        assert_equal "https://example.com/avatar.jpg", user.avatar_url
      end

      def test_unknown_keys_are_filtered
        user = User.from_hash(full_hash.merge("canPay" => true, "someOtherField" => "value"))

        assert_equal "test-user", user.name
      end
    end

    class OrganizationTest < Minitest::Test
      def test_creates_from_hash
        org = Organization.from_hash({ "name" => "huggingface", "fullname" => "Hugging Face" })

        assert_equal "huggingface", org.name
        assert_equal "Hugging Face", org.fullname
      end

      def test_enterprise_from_is_enterprise_key
        org = Organization.from_hash({ "name" => "myorg", "isEnterprise" => true })

        assert_predicate org, :enterprise?
      end

      def test_not_enterprise_by_default
        org = Organization.from_hash({ "name" => "myorg" })

        refute_predicate org, :enterprise?
      end

      def test_display_name_uses_fullname
        org = Organization.from_hash({ "name" => "hf", "fullname" => "Hugging Face" })

        assert_equal "Hugging Face", org.display_name
      end

      def test_display_name_falls_back_to_name
        org = Organization.from_hash({ "name" => "hf" })

        assert_equal "hf", org.display_name
      end

      def test_avatar_url_camelcase_transform
        org = Organization.from_hash({ "name" => "hf", "avatarUrl" => "https://example.com/org.jpg" })

        assert_equal "https://example.com/org.jpg", org.avatar_url
      end

      def test_inspect_includes_name
        org = Organization.from_hash({ "name" => "hf", "fullname" => "Hugging Face" })

        assert_includes org.inspect, "hf"
      end
    end
  end
end
