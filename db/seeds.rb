# Demo user for local walkthrough (fake email only — never a real person).
demo = User.find_or_initialize_by(email_address: "demo@daysignal.local")
demo.password = "password123"
demo.location_label = "Lagos, Nigeria"
demo.latitude = 6.5244
demo.longitude = 3.3792
demo.timezone = "Africa/Lagos"
demo.alert_time = Time.zone.parse("07:00")
demo.rain_threshold = 50
demo.alerts_enabled = true
demo.save!

puts "Seeded demo user: #{demo.email_address} / password123 (Africa/Lagos 07:00)"
