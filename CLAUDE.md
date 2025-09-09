# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kiddo is a Rails 8.0 application using modern Rails conventions and tooling. The application follows standard Rails architecture with SQLite as the database and uses Rails' built-in Solid Cache, Solid Queue, and Solid Cable for caching, background jobs, and real-time features.

## Key Technologies

- **Rails 8.0.2+** - Modern Rails with new defaults
- **SQLite 3** - Primary database (2.1+)
- **Puma** - Web server
- **Importmap** - JavaScript module management
- **Turbo & Stimulus** - Hotwire for SPA-like behavior
- **Propshaft** - Modern asset pipeline
- **Kamal** - Docker-based deployment tool
- **Thruster** - HTTP asset caching/compression

## Development Commands

### Server and Development
- `bin/dev` - Start the development server (uses bin/rails server)
- `bin/rails server` - Start Rails server directly
- `bundle exec rails server` - Alternative server start

### Database
- `bin/rails db:create` - Create database
- `bin/rails db:migrate` - Run migrations  
- `bin/rails db:seed` - Load seed data
- `bin/rails db:prepare` - Setup database (create if needed, or migrate)
- `bin/rails db:reset` - Drop, create, migrate, and seed

### Testing
- `bin/rails test` - Run all tests except system tests
- `bin/rails test:db` - Reset database and run tests
- `bin/rails test test/models/` - Run specific test directory
- `bin/rails test test/models/user_test.rb` - Run specific test file

### Code Quality
- `bin/rubocop` - Run RuboCop linter (uses rails-omakase style)
- `bin/brakeman` - Run security analysis
- `bundle exec rubocop` - Alternative RuboCop invocation

### Asset Management
- `bin/rails assets:precompile` - Precompile assets
- `bin/rails importmap:install` - Setup importmap
- `bin/rails stimulus:manifest:update` - Update Stimulus manifest

### Background Jobs
- `bin/rails solid_queue:start` - Start Solid Queue supervisor for background jobs

### Deployment
- `bin/kamal` - Kamal deployment commands
- `bin/thrust` - Thruster HTTP acceleration

## Architecture Notes

### Application Structure
- **Module Name**: `Kiddo` (config/application.rb:9)
- **Rails Version**: 8.0 with modern defaults
- **Autoloading**: Uses Zeitwerk with `config.autoload_lib(ignore: %w[assets tasks])`
- **Browser Support**: Only modern browsers supporting webp, web push, import maps, CSS nesting, and CSS :has

### Key Configuration
- **Database**: SQLite 3 with Solid Cache, Solid Queue, and Solid Cable
- **Asset Pipeline**: Propshaft (modern replacement for Sprockets)
- **JavaScript**: Importmap with Turbo and Stimulus
- **Code Style**: RuboCop Rails Omakase configuration
- **Testing**: Standard Rails testing with parallel execution enabled

### Security Features
- Modern browser requirement enforced in ApplicationController
- Brakeman security scanning configured
- Standard Rails security defaults

### Deployment Ready
- Docker support with Dockerfile
- Kamal deployment configuration
- Thruster for HTTP acceleration and caching
- Production-ready with proper asset handling

## Common Patterns

### Testing
Tests use standard Rails testing with `test/test_helper.rb` configuring parallel execution and fixtures. System tests use Capybara with Selenium WebDriver.

### Background Jobs
Use Solid Queue (Rails' new default) instead of Sidekiq or other background job processors.

### Real-time Features  
Solid Cable provides WebSocket functionality as Rails' default cable adapter.

### Caching
Solid Cache provides database-backed caching instead of Redis.