import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="roi-calculator"
export default class extends Controller {
  static targets = ["revenue", "percent", "result", "monthly"]
  
  connect() {
    this.calculateROI()
    
    // Add event listeners to inputs
    this.revenueTarget.addEventListener('input', this.calculateROI.bind(this))
    this.percentTarget.addEventListener('input', this.calculateROI.bind(this))
  }
  
  calculateROI() {
    // Get values from inputs, remove commas and convert to numbers
    const revenue = parseFloat(this.revenueTarget.value.replace(/,/g, '')) || 0
    const percent = parseFloat(this.percentTarget.value) || 0
    
    // Calculate annual loss
    const annualLoss = revenue * (percent / 100)
    
    // Calculate monthly savings
    const monthlySavings = annualLoss / 12
    
    // Format results with commas
    const formattedAnnualLoss = annualLoss.toLocaleString('en-US', {
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    })
    
    const formattedMonthlySavings = monthlySavings.toLocaleString('en-US', {
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    })
    
    // Update the results
    this.resultTarget.value = formattedAnnualLoss
    this.monthlyTarget.textContent = `$${formattedMonthlySavings}`
  }
}