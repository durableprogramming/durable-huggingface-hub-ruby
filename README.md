# HuggingFace Hub Ruby

A pure Ruby implementation of the HuggingFace Hub client library. This library provides a complete, production-ready interface to HuggingFace Hub for downloading models, datasets, and managing repositories - with zero Python dependencies.

## Features

- **Pure Ruby Implementation**: No Python required - runs entirely in Ruby
- **Complete Hub API**: Download models, datasets, and manage repositories
- **Smart Caching**: ETag-based validation with symlink optimization for storage efficiency
- **Authentication**: Full token management with multiple authentication methods
- **Progress Tracking**: Built-in progress bars for uploads and downloads
- **Offline Mode**: Work with cached models when offline
- **Repository Management**: Create, delete, and manage Hub repositories
- **File Operations**: Upload, download, and delete files with LFS support
- **Model Cards**: Read and write model, dataset, and space cards
- **Production Ready**: Comprehensive error handling, retries, and logging
- **Type Safe**: Validation and type checking throughout
- **Well Documented**: Extensive API documentation and usage examples

## Quick Start

```ruby
require 'huggingface_hub'

# Download a file from a model repository
HuggingfaceHub.hf_hub_download(
  repo_id: 'gpt2',
  filename: 'config.json'
)

# Or use the API client directly
api = HuggingfaceHub::HfApi.new
models = api.list_models(filter: 'text-generation')
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'huggingface_hub'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install huggingface_hub
```

## Requirements

- Ruby 3.0 or higher
- No Python dependencies required

## Usage

### Downloading Files

Download a specific file from a repository:

```ruby
require 'huggingface_hub'

# Download a model configuration file
config_path = HuggingfaceHub.hf_hub_download(
  repo_id: 'bert-base-uncased',
  filename: 'config.json'
)

# Download from a specific revision
model_path = HuggingfaceHub.hf_hub_download(
  repo_id: 'gpt2',
  filename: 'pytorch_model.bin',
  revision: 'main'
)

# Download with authentication
private_file = HuggingfaceHub.hf_hub_download(
  repo_id: 'private/model',
  filename: 'model.safetensors',
  token: ENV['HF_TOKEN']
)
```

### Downloading Entire Repositories

Download all files from a repository:

```ruby
# Download entire model repository
local_dir = HuggingfaceHub.snapshot_download(
  repo_id: 'gpt2',
  revision: 'main'
)

# Download only specific file patterns
filtered_dir = HuggingfaceHub.snapshot_download(
  repo_id: 'bert-base-uncased',
  allow_patterns: ['*.json', '*.txt'],
  ignore_patterns: ['*.bin']
)
```

### Authentication

Multiple ways to authenticate:

```ruby
# Login interactively
HuggingfaceHub.login

# Login with token
HuggingfaceHub.login(token: 'hf_...')

# Use environment variable
ENV['HF_TOKEN'] = 'hf_...'

# Pass token directly to API calls
api = HuggingfaceHub::HfApi.new(token: 'hf_...')

# Check current user
user_info = api.whoami
puts "Logged in as: #{user_info['name']}"
```

### Repository Management

Create and manage repositories:

```ruby
api = HuggingfaceHub::HfApi.new

# Create a new model repository
url = api.create_repo(
  repo_id: 'my-awesome-model',
  repo_type: 'model',
  private: false
)

# Check if repository exists
exists = api.repo_exists(repo_id: 'my-awesome-model')

# Get repository information
info = api.model_info(repo_id: 'gpt2')
puts "Model tags: #{info.tags}"
puts "Last modified: #{info.last_modified}"

# Delete a repository
api.delete_repo(repo_id: 'my-test-model')
```

### File Operations

Upload and manage files in repositories:

```ruby
api = HuggingfaceHub::HfApi.new

# Upload a single file
api.upload_file(
  path_or_fileobj: './model.safetensors',
  path_in_repo: 'model.safetensors',
  repo_id: 'my-model'
)

# Upload an entire folder
api.upload_folder(
  folder_path: './my-model',
  repo_id: 'my-model',
  commit_message: 'Upload complete model'
)

# Delete a file
api.delete_file(
  path_in_repo: 'old_model.bin',
  repo_id: 'my-model'
)

# List files in a repository
files = api.list_repo_files(
  repo_id: 'gpt2',
  revision: 'main'
)
```

### Searching and Listing

Find models, datasets, and spaces:

```ruby
api = HuggingfaceHub::HfApi.new

# List all text generation models
models = api.list_models(
  filter: 'text-generation',
  sort: 'downloads',
  limit: 10
)

models.each do |model|
  puts "#{model.id} - #{model.downloads} downloads"
end

# List datasets
datasets = api.list_datasets(
  filter: 'translation',
  language: 'en'
)

# List spaces
spaces = api.list_spaces(
  filter: 'gradio',
  limit: 5
)
```

### Working with Model Cards

Read and write repository cards:

```ruby
# Load a model card
card = HuggingfaceHub::ModelCard.load(repo_id: 'gpt2')
puts card.data.tags
puts card.text

# Create a new model card
card = HuggingfaceHub::ModelCard.new(
  text: "# My Model\n\nThis is my awesome model.",
  data: {
    language: 'en',
    license: 'apache-2.0',
    tags: ['text-generation']
  }
)

# Save to repository
card.push_to_hub(repo_id: 'my-model')
```

### Caching and Offline Mode

Control caching behavior:

```ruby
# Specify custom cache directory
HuggingfaceHub.config.cache_dir = '/path/to/cache'

# Enable offline mode (only use cached files)
HuggingfaceHub.config.offline = true

# Scan cache to see what's stored
cache_info = HuggingfaceHub.scan_cache_dir

cache_info.repos.each do |repo|
  puts "#{repo.repo_id}: #{repo.size_on_disk_str}"
end

# Clean up cache
strategy = cache_info.delete_revisions(*old_revisions)
strategy.execute
```

### Error Handling

The library provides detailed error messages:

```ruby
begin
  HuggingfaceHub.hf_hub_download(
    repo_id: 'nonexistent/model',
    filename: 'config.json'
  )
rescue HuggingfaceHub::RepositoryNotFoundError => e
  puts "Repository not found: #{e.message}"
rescue HuggingfaceHub::RevisionNotFoundError => e
  puts "Revision not found: #{e.message}"
rescue HuggingfaceHub::EntryNotFoundError => e
  puts "File not found: #{e.message}"
rescue HuggingfaceHub::HfHubHTTPError => e
  puts "HTTP error: #{e.message}"
  puts "Status code: #{e.response.status}"
end
```

### Configuration

Configure library behavior via environment variables:

```bash
# Authentication
export HF_TOKEN='hf_...'

# Cache location
export HF_HOME=~/.cache/huggingface
export HF_HUB_CACHE=~/.cache/huggingface/hub

# Hub endpoint (for custom/enterprise instances)
export HF_ENDPOINT=https://huggingface.co

# Behavior
export HF_HUB_OFFLINE=1                    # Enable offline mode
export HF_HUB_DISABLE_PROGRESS_BARS=1      # Hide progress bars
export HF_HUB_DISABLE_TELEMETRY=1          # Opt out of telemetry
```

Or configure programmatically:

```ruby
HuggingfaceHub.configure do |config|
  config.cache_dir = '/custom/cache/path'
  config.endpoint = 'https://huggingface.co'
  config.offline = false
  config.progress_bars = true
  config.token = ENV['HF_TOKEN']
end
```

## API Reference

See the [API Documentation](https://rubydoc.info/gems/huggingface_hub) for complete reference.

### Core Classes

- **HfApi**: Main API client for all Hub operations
- **ModelCard**, **DatasetCard**, **SpaceCard**: Repository card management
- **CacheManager**: Cache inspection and cleanup

### Core Functions

- `hf_hub_download`: Download a single file from a repository
- `snapshot_download`: Download an entire repository
- `login`/`logout`: Authentication management
- `scan_cache_dir`: Inspect cached files

## Architecture

The library is organized into modular components:

```
lib/durable_huggingface_hub/
├── hf_api.rb           # Main API client
├── file_download.rb    # Download utilities
├── constants.rb        # Configuration constants
├── errors.rb           # Error hierarchy
├── authentication.rb   # Token management
├── cache.rb            # Caching system
├── repository_card.rb  # Model/dataset cards
└── utils/              # Utility modules
```

## Design Philosophy

This library follows Durable Programming's core principles:

- **Pragmatic Problem-Solving**: Solve real-world ML deployment needs with practical solutions
- **Sustainability**: Design for long-term maintenance and evolution
- **Quality**: Comprehensive testing, validation, and error handling
- **Transparency**: Clear documentation and honest capability representation
- **Incremental Improvement**: Build on proven patterns from the Python implementation

## Feature Comparison with Python Client

This Ruby implementation aims to provide feature parity with the official Python `huggingface_hub` library while following Ruby conventions. The table below tracks implementation progress:

### Core Features

| Feature | Python | Ruby | Status |
|---------|--------|------|--------|
| **File Operations** |
| Download single file (`hf_hub_download`) | ✓ | ✓ | Complete |
| Download repository snapshot | ✓ | ✓ | Complete |
| Upload single file | ✓ | ✓ | Complete |
| Upload folder | ✓ | ✓ | Complete |
| Delete files | ✓ | ✓ | Complete |
| **Authentication** |
| Token management | ✓ | ✓ | Complete |
| Login/logout | ✓ | ✓ | Complete |
| User info (`whoami`) | ✓ | ✓ | Complete |
| Git credential integration | ✓ | ✓ | Complete |
| **Repository Management** |
| Create repository | ✓ | ✓ | Complete |
| Delete repository | ✓ | ✓ | Complete |
| Update repository visibility | ✓ | ✓ | Complete |
| Repository info | ✓ | ✓ | Complete |
| Check repository exists | ✓ | ✓ | Complete |
| List repository files | ✓ | ✓ | Complete |
| **Search & Discovery** |
| List models | ✓ | ✓ | Complete |
| List datasets | ✓ | ✓ | Complete |
| List spaces | ✓ | ✓ | Complete |
| Filter by tags/author | ✓ | ✓ | Complete |
| **Cache Management** |
| Scan cache directory | ✓ | ✓ | Complete |
| Delete cached revisions | ✓ | ✓ | Complete |
| Cache info dataclasses | ✓ | ✓ | Complete |
| **Repository Cards** |
| Load model cards | ✓ | ✓ | Complete |
| Create model cards | ✓ | ✓ | Complete |
| Update model cards | ✓ | ✓ | Complete |
| Dataset cards | ✓ | ✓ | Complete |
| Space cards | ✓ | ✓ | Complete |

### Advanced Features

| Feature | Python | Ruby | Status |
|---------|--------|------|--------|
| **Inference** |
| Inference client | ✓ | ✗ | Not planned v1.0 |
| Inference endpoints | ✓ | ✗ | Not planned v1.0 |
| **Community Features** |
| Discussions | ✓ | ✗ | Not planned v1.0 |
| Pull requests | ✓ | ✗ | Not planned v1.0 |
| Comments | ✓ | ✗ | Not planned v1.0 |
| **Spaces** |
| Runtime management | ✓ | ✗ | Not planned v1.0 |
| Secrets management | ✓ | ✗ | Not planned v1.0 |
| Hardware requests | ✓ | ✗ | Not planned v1.0 |
| **Other** |
| Webhooks server | ✓ | ✗ | Not planned v1.0 |
| Collections | ✓ | ✗ | Not planned v1.0 |
| OAuth | ✓ | ✗ | Not planned v1.0 |
| HfFileSystem (fsspec) | ✓ | ✗ | Not planned v1.0 |
| TensorBoard integration | ✓ | ✗ | Not planned v1.0 |

**Legend:**
- ✓ Implemented
- ⚠️ Planned for v1.0
- ✗ Not planned for v1.0

The Ruby implementation focuses on core functionality that Ruby developers need for downloading models and datasets, managing repositories, and basic Hub interactions. Advanced features like inference clients and community features may be added in future versions based on community feedback.

## Ruby-Specific Design Choices

While maintaining API compatibility where practical, this Ruby implementation:

- Uses Ruby idioms and conventions (snake_case, blocks, keyword arguments)
- Leverages Ruby's standard library for HTTP and file operations
- Employs Ruby-native gems for validation and type checking
- Provides Ruby-friendly error handling with proper exception hierarchy
- Uses Ruby's module system for code organization
- Follows Ruby community standards for gem structure and distribution

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for:

- Development setup instructions
- Code style guidelines
- Testing requirements
- Pull request process

## Development

Clone the repository:

```bash
git clone https://github.com/durableprogramming/huggingface-hub-ruby.git
cd huggingface-hub-ruby
```

Install dependencies:

```bash
bundle install
```

Run tests:

```bash
bundle exec rake test
```

Run linter:

```bash
bundle exec rubocop
```

## Testing

The library includes comprehensive tests:

```bash
# Run all tests
bundle exec rake test

# Run specific test file
bundle exec ruby test/huggingface_hub/hf_api_test.rb

# Run with coverage
bundle exec rake test:coverage
```

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

This is a pure Ruby port of the [HuggingFace Hub Python library](https://github.com/huggingface/huggingface_hub). We are grateful to the HuggingFace team for creating the original library and for their contributions to open-source AI tooling.

## Support

- Documentation: [https://rubydoc.info/gems/huggingface_hub](https://rubydoc.info/gems/huggingface_hub)
- Issues: [GitHub Issues](https://github.com/durableprogramming/huggingface-hub-ruby/issues)
- Email: commercial@durableprogramming.com

## Roadmap

### v0.2.0 (Current) - Feature Complete ✓
- ✓ Constants and configuration
- ✓ Error hierarchy
- ✓ Authentication (login, logout, whoami)
- ✓ File download with caching
- ✓ File upload operations (single file and folders)
- ✓ Repository creation, deletion, and management
- ✓ Repository information (models, datasets, spaces)
- ✓ Search and listing (models, datasets, spaces)
- ✓ Repository cards (model, dataset, space)
- ✓ Complete cache management with deletion support
- ✓ LFS detection and handling

### Planned for v1.0.0
- [ ] Additional repository management features (move, duplicate, update settings)
- [ ] Comprehensive integration testing with live Hub
- [ ] Production-ready error handling and retry logic
- [ ] Performance optimizations
- [ ] Complete documentation and usage examples

### Future Considerations
Advanced features from the Python client may be added based on community needs:
- Inference client and endpoints
- Community features (discussions, PRs)
- Spaces runtime management
- Webhooks and collections
- OAuth integration

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.
