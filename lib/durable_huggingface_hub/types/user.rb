# frozen_string_literal: true

require_relative "../types"

module DurableHuggingfaceHub
  module Types
    # Information about a HuggingFace Hub user.
    #
    # @example Creating a User from API response
    #   user = User.from_hash({
    #     "name" => "john_doe",
    #     "fullname" => "John Doe",
    #     "email" => "john@example.com",
    #     "isPro" => false
    #   })
    #
    # @example Accessing user information
    #   user.name      # => "john_doe"
    #   user.fullname  # => "John Doe"
    #   user.pro?      # => false
    class User < DurableHuggingfaceHub::Struct
      include Loadable

      # @!attribute [r] type
      #   @return [String, nil] User type (e.g., "user")
      attribute :type, Types::OptionalString.default(nil)

      # @!attribute [r] id
      #   @return [String, nil] User ID
      attribute :id, Types::OptionalString.default(nil)

      # @!attribute [r] name
      #   @return [String] Username
      attribute :name, Types::String

      # @!attribute [r] fullname
      #   @return [String, nil] Full display name
      attribute :fullname, Types::OptionalString.default(nil)

      # @!attribute [r] email
      #   @return [String, nil] Email address
      attribute :email, Types::OptionalString.default(nil)

      # @!attribute [r] avatar_url
      #   @return [String, nil] Avatar image URL
      attribute :avatar_url, Types::OptionalString.default(nil)

      # @!attribute [r] is_pro
      #   @return [Boolean, nil] Whether user has Pro subscription
      attribute :is_pro, Types::OptionalBool.default(nil)

      # @!attribute [r] orgs
      #   @return [Array<Hash>, nil] Organizations the user belongs to
      attribute :orgs, Types::Array.of(Types::Hash).optional.default(nil)

      # @!attribute [r] auth
      #   @return [Hash, nil] Authentication information including token details
      attribute :auth, Types::Hash.optional.default(nil)

      # Transform isPro from API to is_pro
      def self.from_hash(data)
        transformed = data.dup
        if transformed.key?("isPro") && !transformed.key?("is_pro")
          transformed["is_pro"] = transformed.delete("isPro")
        elsif transformed.key?(:isPro) && !transformed.key?(:is_pro)
          transformed[:is_pro] = transformed.delete(:isPro)
        end

        if transformed.key?("avatarUrl") && !transformed.key?("avatar_url")
          transformed["avatar_url"] = transformed.delete("avatarUrl")
        elsif transformed.key?(:avatarUrl) && !transformed.key?(:avatar_url)
          transformed[:avatar_url] = transformed.delete(:avatarUrl)
        end

        new(transformed)
      end

      # Checks if the user has a Pro subscription.
      #
      # @return [Boolean] True if Pro user
      def pro?
        is_pro == true
      end

      # Returns the display name (fullname if available, otherwise username).
      #
      # @return [String] Display name
      def display_name
        fullname || name
      end

      # Returns a short description of the user.
      #
      # @return [String] Description string
      def to_s
        display_name
      end

      # Returns a detailed inspection string.
      #
      # @return [String] Inspection string
      def inspect
        "#<#{self.class.name} name=#{name.inspect} fullname=#{fullname.inspect} pro=#{pro?}>"
      end
    end

    # Information about a HuggingFace Hub organization.
    #
    # @example Creating an Organization from API response
    #   org = Organization.from_hash({
    #     "name" => "huggingface",
    #     "fullname" => "Hugging Face",
    #     "isEnterprise" => true
    #   })
    #
    # @example Accessing organization information
    #   org.name        # => "huggingface"
    #   org.fullname    # => "Hugging Face"
    #   org.enterprise? # => true
    class Organization < DurableHuggingfaceHub::Struct
      include Loadable

      # @!attribute [r] name
      #   @return [String] Organization name/ID
      attribute :name, Types::String

      # @!attribute [r] fullname
      #   @return [String, nil] Full display name
      attribute :fullname, Types::OptionalString.default(nil)

      # @!attribute [r] avatar_url
      #   @return [String, nil] Organization avatar URL
      attribute :avatar_url, Types::OptionalString.default(nil)

      # @!attribute [r] is_enterprise
      #   @return [Boolean, nil] Whether this is an Enterprise organization
      attribute :is_enterprise, Types::OptionalBool.default(nil)

      # Transform isEnterprise from API to is_enterprise
      def self.from_hash(data)
        transformed = data.dup
        if transformed.key?("isEnterprise") && !transformed.key?("is_enterprise")
          transformed["is_enterprise"] = transformed.delete("isEnterprise")
        elsif transformed.key?(:isEnterprise) && !transformed.key?(:is_enterprise)
          transformed[:is_enterprise] = transformed.delete(:isEnterprise)
        end

        if transformed.key?("avatarUrl") && !transformed.key?("avatar_url")
          transformed["avatar_url"] = transformed.delete("avatarUrl")
        elsif transformed.key?(:avatarUrl) && !transformed.key?(:avatar_url)
          transformed[:avatar_url] = transformed.delete(:avatarUrl)
        end

        new(transformed)
      end

      # Checks if this is an Enterprise organization.
      #
      # @return [Boolean] True if Enterprise
      def enterprise?
        is_enterprise == true
      end

      # Returns the display name (fullname if available, otherwise name).
      #
      # @return [String] Display name
      def display_name
        fullname || name
      end

      # Returns a short description of the organization.
      #
      # @return [String] Description string
      def to_s
        display_name
      end

      # Returns a detailed inspection string.
      #
      # @return [String] Inspection string
      def inspect
        "#<#{self.class.name} name=#{name.inspect} fullname=#{fullname.inspect} " \
          "enterprise=#{enterprise?}>"
      end
    end
  end
end
