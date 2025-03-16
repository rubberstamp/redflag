# CLAUDE.md - Coding Guidelines for RedFlag App

## Build/Test/Lint Commands
- Run all tests: `bin/rails test`
- Run single test: `bin/rails test TEST=test/path/to/test_file.rb:LINE_NUMBER`
- Run system tests: `bin/rails test:system`
- Lint with RuboCop: `bin/rubocop`
- Start development server: `bin/rails server`
- Run console: `bin/rails console`

## Code Style Guidelines
- **Ruby/Rails**: Follow Rails Omakase style (rubocop-rails-omakase)
- **Styling**: Use Tailwind CSS inline for all styling
- **Naming**: Use snake_case for variables/methods, CamelCase for classes
- **Imports**: Order gems alphabetically in Gemfile
- **Security**: Use QuickBooks API gems, ensure no data storage between sessions
- **Error Handling**: Use Rails error handling patterns with proper logging
- **JavaScript**: Use Stimulus controllers for interactive elements
- **Architecture**: Maintain stateless design with proper encryption for temp data
- **Testing**: Write comprehensive tests for all features, aim for high coverage