# Central mail defaults from ENV (see .env.example).
Rails.application.configure do
  from = ENV.fetch("MAILER_FROM", "alerts@example.com")
  config.action_mailer.default_options = { from: from }

  host = ENV.fetch("APP_HOST", "localhost:3000")
  protocol = host.include?("localhost") ? "http" : "https"
  config.action_mailer.default_url_options = { host: host, protocol: protocol }
end
