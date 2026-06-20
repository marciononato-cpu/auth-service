class RateLimitingError < StandardError
  attr_reader :retry_after

  def initialize(retry_after)
    @retry_after = retry_after
    super("Rate limit exceeded. Try again in #{retry_after} seconds.")
  end
end
