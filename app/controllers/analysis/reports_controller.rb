class Analysis::ReportsController < ApplicationController
  def sample
    # In a real application, this would be loaded from QuickBooks API
    # For now, we're using dummy data
    @report_data = {
      scan_date: Time.now,
      account_name: "Acme Corp",
      risk_score: 42,
      total_transactions: 1245,
      flagged_transactions: 37,
      risk_categories: [
        { name: "Unusual Spending", count: 12, severity: "high" },
        { name: "Duplicate Payments", count: 8, severity: "high" },
        { name: "Round Amount Transactions", count: 7, severity: "medium" },
        { name: "New Vendors", count: 5, severity: "low" },
        { name: "Off-hours Transactions", count: 3, severity: "medium" },
        { name: "End-of-period Transactions", count: 2, severity: "low" }
      ],
      top_flags: [
        {
          id: "TXN-1234",
          date: 2.days.ago,
          amount: 12500.00,
          vendor: "ConsultCo Services",
          flags: ["Unusual Spending", "New Vendor"],
          risk_score: 87,
          description: "Consulting services"
        },
        {
          id: "TXN-1189",
          date: 5.days.ago,
          amount: 2499.99,
          vendor: "Office Solutions Inc",
          flags: ["Duplicate Payment"],
          risk_score: 92,
          description: "Office furniture"
        },
        {
          id: "TXN-1190",
          date: 5.days.ago,
          amount: 2499.99,
          vendor: "Office Solutions Inc",
          flags: ["Duplicate Payment"],
          risk_score: 92,
          description: "Office furniture"
        },
        {
          id: "TXN-1201",
          date: 3.days.ago,
          amount: 5000.00,
          vendor: "Marketing Services LLC",
          flags: ["Round Amount", "Off-hours Transaction"],
          risk_score: 65,
          description: "Marketing campaign"
        },
        {
          id: "TXN-1242",
          date: 1.day.ago,
          amount: 3750.00,
          vendor: "Tech Suppliers",
          flags: ["End-of-period Transaction"],
          risk_score: 45,
          description: "Electronics purchase"
        }
      ],
      trend_data: {
        labels: ["Jan", "Feb", "Mar", "Apr", "May", "Jun"],
        datasets: [
          {
            name: "High Risk Flags",
            data: [5, 7, 4, 6, 12, 20]
          },
          {
            name: "Medium Risk Flags",
            data: [12, 9, 15, 14, 18, 10]
          },
          {
            name: "Low Risk Flags",
            data: [8, 10, 7, 9, 12, 7]
          }
        ]
      }
    }
  end
end