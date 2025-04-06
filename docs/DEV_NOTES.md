# Development Notes for RedFlag

## Running the Application Locally

There are two ways to run the application in development:

### Option 1: Simple Development Mode

```bash
bin/dev_fixed
```

This will start:
- Rails server on port 3000
- Tailwind CSS watcher for styling

Note: Background job processing is disabled in this mode for simplicity.

### Option 2: Full Development Mode

Run each component in a separate terminal:

```bash
# Terminal 1: Rails server
bin/rails server

# Terminal 2: Tailwind CSS watcher
bin/rails tailwindcss:watch
```

For background job processing, SolidQueue needs additional configuration:

1. SolidQueue database configuration is in progress
2. Currently, we use the `:async` adapter for background jobs in development
3. In production, the application uses SolidQueue with database backends

## Known Issues

### SolidQueue Database Configuration

The application is configured to use SolidQueue with multiple databases, but there are issues with the development setup:

1. The `db/queue_migrate` directory contains migrations for SolidQueue tables
2. The migrations run successfully with `bin/rails db:migrate:queue`
3. However, SolidQueue cannot find its tables at runtime

This is a configuration issue that needs to be resolved for full background job processing.

### Workaround for Development

In development mode, we're using Rails' built-in `:async` adapter instead of SolidQueue. This allows basic job processing without the complexity of the multi-database setup.

For a full production-like environment with SolidQueue, further configuration is needed.