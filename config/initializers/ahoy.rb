class Ahoy::Store < Ahoy::DatabaseStore
  # Guest RSVP links carry invite tokens, so keep them out of stored URLs.
  RSVP_TOKEN_PATH = %r{/rsvp/(?!resend\b)[^/?#]+}

  def self.scrub_url(url)
    url&.gsub(RSVP_TOKEN_PATH, "/rsvp/FILTERED")
  end

  def track_visit(data)
    data[:landing_page] = self.class.scrub_url(data[:landing_page])
    data[:referrer]     = self.class.scrub_url(data[:referrer])
    super
  end
end

# Server-side events only: no JavaScript tracking API, no geocoding, no IP
# addresses (the visits table has no ip column). A visit is only recorded when
# an event is tracked.
Ahoy.api = false
Ahoy.geocode = false
Ahoy.server_side_visits = :when_needed

# Integration tests have no browser user agent, which Ahoy would treat as a bot.
Ahoy.track_bots = Rails.env.test?
