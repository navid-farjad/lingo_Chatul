# Cross-Origin Resource Sharing (CORS) so the React web app can hit this API
# from a different origin during development. In production we lock to the
# real frontend domain.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    if Rails.env.production?
      origins "https://app.lingochatul.com",
              "https://lingochatul.com",
              "https://www.lingochatul.com"
    else
      origins "http://localhost:5173", "http://127.0.0.1:5173", "http://localhost:3000"
    end

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ["Authorization"],
      max_age: 600
  end
end
