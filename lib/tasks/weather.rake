namespace :weather do
  desc "Fetch forecast + print AlertEvaluator decision for a user (EMAIL=demo@daysignal.local)"
  task evaluate: :environment do
    email = ENV.fetch("EMAIL", "demo@daysignal.local")
    user = User.find_by!(email_address: email)

    unless user.preferences_complete?
      abort "User #{email} is missing location/timezone preferences"
    end

    puts "User: #{user.email_address} @ #{user.location_label} (#{user.latitude}, #{user.longitude})"
    puts "Threshold: #{user.rain_threshold}% | timezone: #{user.timezone}"

    forecast = WeatherClient.fetch(user.latitude, user.longitude)
    decision = AlertEvaluator.call(forecast, user.rain_threshold, location_label: user.location_label)

    puts "POP: #{forecast.precipitation_probability}% | summary: #{forecast.summary}"
    puts "wind_speed: #{forecast.wind_speed} m/s"
    puts "trigger?: #{decision.trigger?}"
    puts "reason: #{decision.reason}"
    puts "recommendation: #{decision.recommendation}"
  end
end
