require "aws-sdk-s3"

module ContentPipeline
  # Uploads bytes to Cloudflare R2 (S3-compatible) and returns the public URL.
  # Bucket is `lang`; we use a flat key scheme:
  #   images/{language_code}/{word_native_or_id}.jpg
  #   audio/{language_code}/{word_native_or_id}.mp3
  class R2Uploader
    def initialize(
      bucket: ENV.fetch("R2_BUCKET"),
      public_url: ENV.fetch("R2_PUBLIC_URL"),
      access_key_id: ENV.fetch("R2_ACCESS_KEY_ID"),
      secret_access_key: ENV.fetch("R2_SECRET_ACCESS_KEY"),
      endpoint: ENV.fetch("R2_ENDPOINT")
    )
      @bucket = bucket
      @public_url = public_url.chomp("/")
      @client = Aws::S3::Client.new(
        region: "auto",
        endpoint: endpoint,
        access_key_id: access_key_id,
        secret_access_key: secret_access_key,
        # R2 requires path-style addressing
        force_path_style: true
      )
    end

    # @param key [String]  object key, e.g. "images/el/kalimera.jpg"
    # @param bytes [String]  binary body
    # @param content_type [String]
    # @return [String]  public URL where the object can be fetched
    def upload(key:, bytes:, content_type:)
      @client.put_object(
        bucket: @bucket,
        key: key,
        body: bytes,
        content_type: content_type,
        cache_control: "public, max-age=31536000, immutable"
      )
      "#{@public_url}/#{key}"
    end
  end
end
