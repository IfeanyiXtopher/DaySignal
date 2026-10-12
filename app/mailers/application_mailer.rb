class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAILER_FROM", "alerts@example.com") }
  layout "mailer"
end
