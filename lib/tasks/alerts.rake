namespace :alerts do
  desc "Run WeatherAlertJob for one user (EMAIL=demo@weathercheck.local). Uses Letter Opener unless MAILER_DELIVERY_METHOD=smtp."
  task deliver_one: :environment do
    email = ENV.fetch("EMAIL", "demo@weathercheck.local")
    user = User.find_by!(email_address: email)
    puts "Enqueueing WeatherAlertJob for #{user.email_address} (id=#{user.id})..."
    # perform_now so you see Letter Opener / SMTP result immediately in this terminal.
    WeatherAlertJob.perform_now(user.id)
    user.reload
    puts "Done. last_alerted_at=#{user.last_alerted_at.inspect}"
    puts "If Letter Opener: check the browser tab that opened (or mail logs)."
  end
end
