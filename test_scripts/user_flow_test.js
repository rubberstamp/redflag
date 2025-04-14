const puppeteer = require('puppeteer');
const fs = require('fs');

// Ensure screenshots directory exists
if (!fs.existsSync('./test_scripts/screenshots')) {
  fs.mkdirSync('./test_scripts/screenshots', { recursive: true });
}

(async () => {
  // Launch browser
  const browser = await puppeteer.launch({
    headless: false, // Set to true for headless testing
    defaultViewport: { width: 1280, height: 800 },
    args: ['--window-size=1280,800'],
    slowMo: 300 // Slow down actions to make them more visible
  });
  
  const page = await browser.newPage();
  
  console.log('🧪 Starting user flow testing...');

  try {
    // Test 1: Homepage and lead capture form
    console.log('Test 1: Testing homepage and initial lead capture form');
    await page.goto('http://localhost:3000');
    await page.screenshot({ path: './test_scripts/screenshots/01_homepage.png' });
    
    // Fill out initial lead form
    await page.waitForSelector('#email');
    await page.type('#email', `test${Date.now()}@example.com`);
    await page.screenshot({ path: './test_scripts/screenshots/02_email_filled.png' });
    
    // Submit form
    await Promise.all([
      page.waitForNavigation({ timeout: 10000 }),
      page.click('#initial-lead-form button[type="submit"]')
    ]);
    
    // Check if we reached the choose_import page
    try {
      await page.waitForSelector('h1:contains("Choose Your Data Source")', { timeout: 5000 });
      console.log('✅ Successfully redirected to choose_import page');
      await page.screenshot({ path: './test_scripts/screenshots/03_choose_import.png' });
    } catch (error) {
      console.error('❌ Failed to reach choose_import page - checking page content');
      await page.screenshot({ path: './test_scripts/screenshots/03_error_redirect.png' });
      const pageContent = await page.content();
      console.log('Current page content:', pageContent.substring(0, 500) + '...');
    }
    
    // Test 2: Choose CSV import (simpler to test than QuickBooks)
    console.log('Test 2: Testing CSV import option');
    
    // Try to navigate directly to the CSV upload page if needed
    try {
      await page.goto('http://localhost:3000/imports/new');
      await page.waitForSelector('form', { timeout: 5000 });
      await page.screenshot({ path: './test_scripts/screenshots/04_csv_upload.png' });
      console.log('✅ Successfully navigated to CSV upload page');
    } catch (error) {
      console.error('❌ Failed to reach CSV upload page:', error.message);
      await page.screenshot({ path: './test_scripts/screenshots/04_error_csv.png' });
    }
    
    // Test 3: Test lead capture page form submission
    console.log('Test 3: Testing full lead capture form');
    try {
      await page.goto('http://localhost:3000/leads/capture');
      
      // Fill out lead capture form
      await page.waitForSelector('form');
      await page.type('input[name="lead[first_name]"]', 'Test');
      await page.type('input[name="lead[last_name]"]', 'User');
      await page.type('input[name="lead[email]"]', `test${Date.now()}@example.com`);
      await page.type('input[name="lead[company]"]', 'Test Company');
      await page.type('input[name="lead[phone]"]', '555-123-4567');
      
      // Select company size from dropdown
      await page.select('select[name="lead[company_size]"]', '11-50 employees');
      
      // Check newsletter checkbox
      const checkbox = await page.$('input[name="lead[newsletter]"]');
      if (checkbox) {
        const checkboxPos = await checkbox.boundingBox();
        await page.mouse.click(checkboxPos.x + 5, checkboxPos.y + 5);
      }
      
      await page.screenshot({ path: './test_scripts/screenshots/05_lead_form_filled.png' });
      
      // Submit the form
      await Promise.all([
        page.waitForNavigation({ timeout: 10000 }),
        page.click('input[type="submit"]')
      ]);
      
      // Check if we reached the CFO consultation page
      await page.screenshot({ path: './test_scripts/screenshots/06_after_lead_submit.png' });
      const url = page.url();
      console.log('Current URL after form submission:', url);
      
      const pageContent = await page.content();
      if (pageContent.includes('Speak with a Financial Expert')) {
        console.log('✅ Successfully redirected to CFO consultation page');
      } else {
        console.log('❓ Page after lead form does not appear to be CFO consultation page');
        console.log('Page title:', await page.title());
      }
    } catch (error) {
      console.error('❌ Error during lead form test:', error.message);
      await page.screenshot({ path: './test_scripts/screenshots/06_error_lead_form.png' });
    }
    
    // Test 4: Navigate directly to the CFO consultation page if needed
    console.log('Test 4: Testing CFO consultation page');
    try {
      await page.goto('http://localhost:3000/leads/cfo_consultation');
      await page.waitForSelector('form[action="/leads/process_consultation"]');
      await page.screenshot({ path: './test_scripts/screenshots/07_cfo_consultation.png' });
      console.log('✅ Successfully loaded CFO consultation page');
      
      // Test skip button
      const skipButtonSelector = 'input[value="Skip to View Report"]';
      await page.waitForSelector(skipButtonSelector);
      
      await Promise.all([
        page.waitForNavigation({ timeout: 10000 }),
        page.click(skipButtonSelector)
      ]);
      
      await page.screenshot({ path: './test_scripts/screenshots/08_after_skip.png' });
      console.log('Current URL after skipping:', page.url());
      console.log('✅ Skip button clicked successfully');
    } catch (error) {
      console.error('❌ Error during CFO consultation test:', error.message);
      await page.screenshot({ path: './test_scripts/screenshots/07_error_cfo.png' });
    }

    console.log('🎉 Testing completed! Check screenshots for visual confirmation.');
    
  } catch (error) {
    console.error('❌ Test failed:', error);
    await page.screenshot({ path: './test_scripts/screenshots/error.png' });
  } finally {
    await browser.close();
  }
})();