# RedFlag

RedFlag is a QuickBooks transaction analysis and fraud detection tool. It helps businesses identify suspicious transactions and protect against financial fraud.

## Features

- QuickBooks integration for accessing financial data
- CSV import for analyzing transactions from any source
- Advanced transaction analysis with multiple detection rules
- Interactive dashboards for reviewing flagged transactions
- Secure, stateless design with proper encryption

## Deployment

This application is automatically deployed to Fly.io when changes are pushed to the main branch.

## Development

To run the application locally:

```bash
bin/dev
```

This will start the web server, CSS watcher, and background job worker.

## Testing

Run the test suite with:

```bash
bin/rails test
```

For system tests:

```bash
bin/rails test:system
```
