class ApplicationMailer < ActionMailer::Base
  default from: "notifications@redflagapp.com",
          reply_to: "support@redflagapp.com"
  layout "mailer"
end
