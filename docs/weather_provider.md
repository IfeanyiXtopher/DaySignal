# Weather provider (MVP)

## Decision

**Provider:** OpenWeatherMap  
**ENV:** `WEATHER_PROVIDER=openweathermap`, `WEATHER_API_KEY=...`

## Endpoint

Free-tier friendly **5 day / 3 hour forecast** (API 2.5):

```
GET https://api.openweathermap.org/data/2.5/forecast
  ?lat={lat}&lon={lon}&appid={key}&units=metric
```

Why not One Call 3.0 for MVP? One Call 3.0 often requires a separate
subscription. The 2.5 forecast endpoint works with a standard free API key and
exposes `pop` (probability of precipitation, 0.0–1.0) on each 3-hour slot.

## Normalization

`WeatherClient` maps the JSON into a `Forecast` value object used by
`AlertEvaluator`. Controllers never call Faraday directly.

See also: [`definitions.md`](definitions.md) for the forecast window and
threshold rules.
