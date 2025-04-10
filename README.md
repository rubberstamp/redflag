# RedFlag - Financial Transaction Red Flag Detector

RedFlag analyzes financial transactions to detect potential fraud, waste, and abuse. It uses statistical analysis to identify unusual patterns and suspicious transactions in your financial data.

## Features

- **QuickBooks Integration**: Securely connect to your QuickBooks account to analyze transactions
- **CSV Upload**: Import transaction data from CSV files for analysis
- **Comprehensive Analysis**: Detects unusual spending patterns, duplicate transactions, round numbers, and more
- **Risk Scoring**: Each potential issue is assigned a risk score to help prioritize investigation efforts
- **Detailed Report**: View a comprehensive report of flagged transactions and recommendations
- **Interactive Dashboards**: Review flagged transactions through an interactive interface
- **Secure Design**: Stateless design with proper encryption for sensitive data

## Getting Started

### Prerequisites

- Ruby 3.2.0
- Rails 8.0.2
- SQLite3
- Node.js and Yarn

### Installation

1. Clone the repository
   ```
   git clone https://github.com/rubberstamp/redflag.git
   cd redflag
   ```

2. Install dependencies
   ```
   bundle install
   yarn install
   ```

3. Set up the database
   ```
   bin/rails db:create db:migrate db:migrate:queue
   ```

4. Start the server
   ```
   bin/dev_fixed
   ```

### Configuration

To enable the QuickBooks integration, you'll need to set up a QuickBooks Developer account and create an application. Then add your credentials to the `config/quickbooks_config.yml` file.

## CSV Import

The CSV import feature allows you to analyze transaction data from CSV files. The system supports various CSV formats, including:

1. **Standard Format** - Includes columns for ID, Date, Amount, Type, Vendor/Customer, and Description
2. **QuickBooks Export** - CSV exported directly from QuickBooks
3. **Bank Export** - Common bank statement export format
4. **Custom Mapping** - For custom CSV formats, with column mapping

### CSV Import Workflow

1. **Upload**: Upload your CSV file
2. **Mapping**: Map CSV columns to required fields (automatic detection for known formats)
3. **Preview**: Review the parsed data and configure detection settings
4. **Analysis**: System analyzes transactions and generates a report

### Supported CSV Columns

The system looks for the following fields in your CSV:
- Transaction ID
- Date
- Amount
- Type/Category
- Vendor/Customer Name
- Description/Memo

## Development

### Running the Application

```bash
bin/dev_fixed
```

This will start the web server and CSS watcher. For full functionality including background jobs, see the DEV_NOTES.md file.

### Running Tests

```bash
bin/rails test
```

For system tests:

```bash
bin/rails test:system
```

### Database Schema

The application uses two main models:
- `QuickbooksProfile`: Stores QuickBooks connection information
- `QuickbooksAnalysis`: Stores analysis data (for both QuickBooks and CSV imports)

## Deployment

The application is configured for deployment on Fly.io. It is automatically deployed when changes are pushed to the main branch.

```bash
bin/deploy_with_redis
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.