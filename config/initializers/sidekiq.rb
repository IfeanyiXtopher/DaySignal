# Sidekiq talks to Redis. REDIS_URL comes from `.env` (local) or the VPS ENV.
# Cron jobs are loaded automatically from config/schedule.yml by the
# sidekiq-cron gem when Sidekiq starts.
redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
