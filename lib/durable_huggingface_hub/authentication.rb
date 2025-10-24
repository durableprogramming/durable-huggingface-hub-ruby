# frozen_string_literal: true

require "io/console"

module DurableHuggingfaceHub
  # Authentication methods for HuggingFace Hub.
  #
  # This module provides methods for logging in and out of HuggingFace Hub,
  # storing authentication tokens securely, and verifying credentials.
  module Authentication
     # Logs in to HuggingFace Hub and stores the authentication token.
     #
     # If a token is provided, it will be validated and stored. If no token
     # is provided and the process is running interactively, the user will
     # be prompted to enter a token.
     #
     # @param token [String, nil] Authentication token
     # @param add_to_git_credential [Boolean] Whether to add token to git credential helper
     # @return [String] The stored token (masked)
     # @raise [DurableHuggingfaceHubError] If token is invalid or login fails
     #
     # @example With explicit token
     #   DurableHuggingfaceHub.login(token: "hf_...")
     #
     # @example Interactive login
     #   DurableHuggingfaceHub.login  # Prompts for token
     #
     # @example Login with git credential storage
     #   DurableHuggingfaceHub.login(token: "hf_...", add_to_git_credential: true)
     def self.login(token: nil, add_to_git_credential: false)
       # Get token from parameter or prompt
       token = obtain_token(token)

       # Validate token format
       unless Utils::Auth.valid_token_format?(token)
         raise ValidationError.new("token", "Invalid token format. Token should start with 'hf_'")
       end

       # Verify token works by calling whoami
       begin
         user_info = whoami(token: token)
       rescue HfHubHTTPError => e
         raise DurableHuggingfaceHubError.new("Login failed: #{e.message}")
       end

       # Store token
       Utils::Auth.write_token_to_file(token)

       # Store in git credential helper if requested
       if add_to_git_credential
         store_git_credential(token)
       end

       # Update configuration
       Configuration.instance.token = token

      # Return user info for CLI
       { name: user_info.name, type: user_info.type || "user" }
     end

     # Logs out of HuggingFace Hub by removing the stored token.
     #
     # @return [Boolean] True if token was removed, false if no token existed
     #
     # @example
     #   DurableHuggingfaceHub.logout
     def self.logout
       result = Utils::Auth.delete_token_file

       # Remove from git credential helper if present
       remove_git_credential

       # Clear from configuration
       Configuration.instance.token = nil

       if result
         puts "Logged out successfully. Token removed."
       else
         puts "No token found to remove."
       end

       result
     end

    # Returns information about the currently authenticated user.
    #
    # Makes a request to the /api/whoami endpoint to retrieve user information.
    #
    # @param token [String, nil] Authentication token (uses stored token if not provided)
    # @return [Hash] User information hash
    # @raise [LocalTokenNotFoundError] If no token is available
    # @raise [HfHubHTTPError] If the API request fails
    #
    # @example
    #   user_info = DurableHuggingfaceHub.whoami
    #   puts user_info["name"]
    #   puts user_info["fullname"]
     def self.whoami(token: nil)
       token = Utils::Auth.get_token!(token: token)

       client = Utils::HttpClient.new(token: token)
       response = client.get("/api/whoami-v2")

       Types::User.from_hash(response.body)
     end

    # Checks if a user is currently logged in (has a valid token).
    #
    # @return [Boolean] True if a token is available
    #
    # @example
    #   if DurableHuggingfaceHub.logged_in?
    #     puts "Already logged in"
    #   end
    def self.logged_in?
      token = Utils::Auth.get_token
      !token.nil? && !token.empty?
    end

     private

       # Checks if git is available on the system.
       #
       # @return [Boolean] True if git is available
       def self.git_available?
         system("which git > /dev/null 2>&1")
       end

       # Stores the token in the git credential helper.
       #
       # @param token [String] Authentication token
       # @return [Boolean] True if stored successfully
       def self.store_git_credential(token)
         # Check if git is available
         return false unless git_available?

         credential_data = <<~CREDENTIAL
           protocol=https
           host=huggingface.co
           username=hf_#{token[3..]}  # Extract token part after 'hf_'
           password=#{token}
         CREDENTIAL

         # Use git credential approve to store the credential
         begin
           IO.popen("git credential approve", "w+") do |io|
             io.write(credential_data)
             io.close_write
             io.read # Consume any output
           end
           $?.success?
         rescue Errno::ENOENT, IOError
           false
         end
       end

      # Removes the token from the git credential helper.
       #
       # @return [Boolean] True if removed successfully
       def self.remove_git_credential
         # Check if git is available
         return false unless git_available?

         # First check if we have a stored token to know what to remove
         token = Utils::Auth.get_token
         return false unless token

         credential_data = <<~CREDENTIAL
           protocol=https
           host=huggingface.co
           username=hf_#{token[3..]}  # Extract token part after 'hf_'
         CREDENTIAL

         # Use git credential reject to remove the credential
         begin
           IO.popen("git credential reject", "w+") do |io|
             io.write(credential_data)
             io.close_write
             io.read # Consume any output
           end
           $?.success?
         rescue Errno::ENOENT, IOError
           false
         end
       end

     # Obtains a token either from parameter or by prompting the user.
     #
     # @param token [String, nil] Provided token
     # @return [String] Token
     # @raise [DurableHuggingfaceHubError] If unable to obtain token
     def self.obtain_token(token)
       return token if token && !token.empty?

         # Check if running interactively
         unless $stdin.respond_to?(:tty?) && $stdin.tty?
           raise DurableHuggingfaceHubError.new(
             "No token provided and not running interactively. " \
             "Please provide a token using the 'token' parameter."
           )
         end

       # Prompt for token
       prompt_for_token
     end

     # Prompts the user to enter their authentication token.
     #
     # The token input is hidden for security.
     #
     # @return [String] Entered token
     # @raise [DurableHuggingfaceHubError] If token entry is cancelled
     def self.prompt_for_token
       puts "\nTo login, you need a User Access Token from https://huggingface.co/settings/tokens"
       puts "You can create a new token or use an existing one."
       puts "\nPaste your token (input will be hidden):"

       # Read token without echoing to terminal
       begin
         if $stdin.respond_to?(:noecho) && $stdin.isatty
           token = $stdin.noecho(&:gets)&.chomp
         else
           # For testing or when noecho is not available
           token = $stdin.gets&.chomp
         end
       rescue Interrupt
         puts "\nLogin cancelled"
         raise DurableHuggingfaceHubError.new("Login cancelled by user")
       end

       if token.nil? || token.empty?
         raise DurableHuggingfaceHubError.new("Token entry cancelled or empty")
       end

       token
     end
  end
end
