# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-01-24

### Added

#### Repository Management
- `HfApi#create_repo` - Create new repositories on the Hub
- `HfApi#delete_repo` - Delete repositories from the Hub
- `HfApi#update_repo_visibility` - Change repository visibility (public/private)
- `HfApi#update_repo_settings` - Update repository settings (LFS, protection, tags, etc.)
- `HfApi#move_repo` - Move or rename repositories
- `HfApi#duplicate_space` - Duplicate Space repositories
- `HfApi#list_repo_files` - List all files in a repository
- `HfApi#list_repo_tree` - Get hierarchical tree structure of repository contents

#### File Upload Operations
- `HfApi#upload_file` - Upload single files to repositories with multipart support
- `HfApi#upload_folder` - Upload entire folders to repositories
- `HfApi#delete_file` - Delete files from repositories
- `HfApi#delete_folder` - Delete folders and their contents from repositories
- LFS file detection and handling for large file uploads

#### Repository Cards
- `RepoCard` base class for repository documentation
- `ModelCard` for machine learning model documentation
- `DatasetCard` for dataset documentation
- `SpaceCard` for Spaces (interactive demos) documentation
- `RepoCard.load` - Load cards from local files
- `RepoCard.from_hub` - Load cards directly from the Hub
- `RepoCard#push_to_hub` - Upload cards to repositories
- Card validation with metadata checking
- YAML frontmatter parsing and generation

#### Cache Management
- `Cache.delete_file_safely` - Delete individual cached files
- `Cache.delete_revision_safely` - Delete entire cached revisions
- `Cache.delete_repository_safely` - Delete cached repositories
- Enhanced cache scanning with file metadata

### Changed
- Improved error handling for authentication operations
- Enhanced HTTP client with better multipart form data support
- Updated documentation with complete API examples

### Fixed
- File download edge cases with missing ETags
- Cache directory creation on first use
- Token file permissions handling

## [0.1.0] - 2025-01-20

### Added

#### Core Infrastructure
- `Configuration` singleton for global settings
- `Constants` module with Hub endpoints and configuration
- Comprehensive error hierarchy (`HfHubHTTPError`, `RepositoryNotFoundError`, etc.)
- `Version` class with semantic versioning support

#### Authentication
- `Authentication.login` - Interactive and programmatic login
- `Authentication.logout` - Remove stored credentials
- `Authentication.whoami` - Get current user information
- Token management with file-based storage
- Git credential helper integration
- Environment variable support (`HF_TOKEN`)

#### File Operations
- `FileDownload.hf_hub_download` - Download single files with caching
- `FileDownload.snapshot_download` - Download entire repositories
- `FileDownload.try_to_load_from_cache` - Check cache without downloading
- ETag-based cache validation
- Symlink-based storage optimization
- Progress bar support for downloads

#### Repository Information
- `HfApi#repo_info` - Get detailed repository information
- `HfApi#model_info` - Get model-specific information
- `HfApi#dataset_info` - Get dataset-specific information
- `HfApi#space_info` - Get Space-specific information
- `HfApi#repo_exists` - Check if repository exists
- `HfApi#get_hf_file_metadata` - Get file metadata without downloading

#### Search and Discovery
- `HfApi#list_models` - List and filter models
- `HfApi#list_datasets` - List and filter datasets
- `HfApi#list_spaces` - List and filter Spaces
- Support for filtering by author, tags, search queries
- Sorting by downloads, likes, creation date, etc.

#### Cache Management
- `Cache.scan_cache_dir` - Analyze cache contents
- `Cache.cached_assets_path` - Get path to cached assets
- Detailed cache statistics and metadata
- Support for custom cache directories

#### Type System
- `Types::ModelInfo` - Model metadata
- `Types::DatasetInfo` - Dataset metadata
- `Types::SpaceInfo` - Space metadata
- `Types::User` - User information
- `Types::CommitInfo` - Git commit details
- `Types::HFCacheInfo` - Cache structure information

#### Utilities
- `Utils::HttpClient` - HTTP client with retry logic and authentication
- `Utils::Retry` - Exponential backoff retry mechanism
- `Utils::Headers` - User-Agent and header management
- `Utils::Auth` - Token resolution and management
- `Utils::Validators` - Input validation helpers
- `Utils::Paths` - Path normalization and utilities
- `Utils::Progress` - Download progress tracking

### Documentation
- Comprehensive README with examples
- API documentation with YARD
- Installation and setup guide
- Configuration examples

[0.2.0]: https://github.com/durableprogramming/huggingface-hub-ruby/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/durableprogramming/huggingface-hub-ruby/releases/tag/v0.1.0
