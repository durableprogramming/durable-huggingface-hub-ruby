# frozen_string_literal: true

require "optparse"
require "json"

module DurableHuggingfaceHub
  # Command-line interface for the Hugging Face Hub
  class CLI
    def initialize(args)
      @args = args
      @command = nil
      @options = {}
    end

    def run
      parse_args
      execute_command
    rescue StandardError => e
      abort "Error: #{e.message}"
    end

    private

    def parse_args
      if @args.empty?
        print_usage
        exit 0
      end

      @command = @args.shift

      OptionParser.new do |opts|
        case @command
        when "login"
          parse_login_options(opts)
        when "logout"
          parse_logout_options(opts)
        when "whoami"
          parse_whoami_options(opts)
        when "download"
          parse_download_options(opts)
        when "info"
          parse_info_options(opts)
        when "list"
          parse_list_options(opts)
        when "scan-cache"
          parse_scan_cache_options(opts)
        when "help", "--help", "-h"
          print_usage
          exit 0
        else
          puts "Unknown command: #{@command}"
          print_usage
          exit 1
        end
      end.parse!(@args)
    end

    def parse_login_options(opts)
      opts.banner = "Usage: dhf login [options]"
      opts.on("-t", "--token TOKEN", "HuggingFace API token") { |v| @options[:token] = v }
      opts.on("--add-to-git-credential", "Add token to git credential store") { @options[:add_to_git_credential] = true }
    end

    def parse_logout_options(opts)
      opts.banner = "Usage: dhf logout"
    end

    def parse_whoami_options(opts)
      opts.banner = "Usage: dhf whoami [options]"
      opts.on("-t", "--token TOKEN", "HuggingFace API token") { |v| @options[:token] = v }
    end

    def parse_download_options(opts)
      opts.banner = "Usage: dhf download REPO_ID [options]"
      opts.on("-f", "--filename FILENAME", "Specific file to download") { |v| @options[:filename] = v }
      opts.on("-r", "--revision REVISION", "Git revision (branch, tag, or commit)") { |v| @options[:revision] = v }
      opts.on("--repo-type TYPE", "Repository type (model, dataset, space)") { |v| @options[:repo_type] = v }
      opts.on("--cache-dir DIR", "Path to cache directory") { |v| @options[:cache_dir] = v }
      opts.on("--snapshot", "Download entire repository snapshot") { @options[:snapshot] = true }
    end

    def parse_info_options(opts)
      opts.banner = "Usage: dhf info REPO_ID [options]"
      opts.on("--repo-type TYPE", "Repository type (model, dataset, space)") { |v| @options[:repo_type] = v }
      opts.on("-r", "--revision REVISION", "Git revision (branch, tag, or commit)") { |v| @options[:revision] = v }
    end

    def parse_list_options(opts)
      opts.banner = "Usage: dhf list TYPE [options]"
      opts.on("--author AUTHOR", "Filter by author") { |v| @options[:author] = v }
      opts.on("--search QUERY", "Search query") { |v| @options[:search] = v }
      opts.on("--limit N", Integer, "Limit number of results") { |v| @options[:limit] = v }
      opts.on("--full", "Return full information") { @options[:full] = true }
    end

    def parse_scan_cache_options(opts)
      opts.banner = "Usage: dhf scan-cache [options]"
      opts.on("--cache-dir DIR", "Path to cache directory") { |v| @options[:cache_dir] = v }
    end

    def execute_command
      case @command
      when "login"
        cmd_login
      when "logout"
        cmd_logout
      when "whoami"
        cmd_whoami
      when "download"
        cmd_download
      when "info"
        cmd_info
      when "list"
        cmd_list
      when "scan-cache"
        cmd_scan_cache
      end
    end

    def cmd_login
      result = DurableHuggingfaceHub.login(
        token: @options[:token],
        add_to_git_credential: @options[:add_to_git_credential] || false
      )
      puts "Successfully logged in as: #{result[:name]} (#{result[:type]})"
    end

    def cmd_logout
      DurableHuggingfaceHub.logout
      puts "Successfully logged out"
    end

    def cmd_whoami
      result = DurableHuggingfaceHub.whoami(token: @options[:token])
      puts JSON.pretty_generate(result)
    end

    def cmd_download
      repo_id = @args.shift
      abort "Error: REPO_ID required" unless repo_id

      if @options[:snapshot]
        path = DurableHuggingfaceHub.snapshot_download(
          repo_id: repo_id,
          revision: @options[:revision],
          repo_type: @options[:repo_type] || "model",
          cache_dir: @options[:cache_dir]
        )
      else
        filename = @options[:filename]
        abort "Error: --filename required for single file download" unless filename

        path = DurableHuggingfaceHub.hf_hub_download(
          repo_id: repo_id,
          filename: filename,
          revision: @options[:revision],
          repo_type: @options[:repo_type] || "model",
          cache_dir: @options[:cache_dir]
        )
      end

      puts "Downloaded to: #{path}"
    end

    def cmd_info
      repo_id = @args.shift
      abort "Error: REPO_ID required" unless repo_id

      repo_type = @options[:repo_type] || "model"
      info = DurableHuggingfaceHub.repo_info(
        repo_id,
        repo_type: repo_type,
        revision: @options[:revision]
      )

      puts JSON.pretty_generate(info.to_h)
    end

    def cmd_list
      type = @args.shift
      abort "Error: TYPE required (models, datasets, or spaces)" unless type

      results = case type
                when "models"
                  DurableHuggingfaceHub.list_models(
                    author: @options[:author],
                    search: @options[:search],
                    limit: @options[:limit],
                    full: @options[:full] || false
                  )
                when "datasets"
                  DurableHuggingfaceHub.list_datasets(
                    author: @options[:author],
                    search: @options[:search],
                    limit: @options[:limit],
                    full: @options[:full] || false
                  )
                when "spaces"
                  DurableHuggingfaceHub.list_spaces(
                    author: @options[:author],
                    search: @options[:search],
                    limit: @options[:limit],
                    full: @options[:full] || false
                  )
                else
                  abort "Error: Unknown type '#{type}'. Must be models, datasets, or spaces"
                end

      results.each do |item|
        puts JSON.pretty_generate(item.to_h)
      end
    end

    def cmd_scan_cache
      info = DurableHuggingfaceHub.scan_cache_dir(cache_dir: @options[:cache_dir])
      puts JSON.pretty_generate(info.to_h)
    end

    def print_usage
      puts <<~USAGE
        Usage: dhf COMMAND [options]

        Commands:
          login                 Login to HuggingFace Hub
          logout                Logout from HuggingFace Hub
          whoami                Display current user information
          download REPO_ID      Download a file or repository
          info REPO_ID          Get information about a repository
          list TYPE             List models, datasets, or spaces
          scan-cache            Scan the local cache directory
          help                  Show this help message

        Examples:
          dhf login --token hf_...
          dhf whoami
          dhf download bert-base-uncased --filename config.json
          dhf download bert-base-uncased --snapshot
          dhf info openai/whisper-large-v3
          dhf list models --author openai --limit 10
          dhf scan-cache

        Use 'dhf COMMAND --help' for more information on a specific command.
      USAGE
    end
  end
end
