# Keep organizers signed in across browser restarts so they don't need a new SMS
# code every visit. The expiry slides: the cookie is re-issued on each request.
Rails.application.config.session_store :cookie_store, key: "_still_on_session", expire_after: 60.days
