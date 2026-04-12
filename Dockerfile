FROM ruby:3.4.2-slim

RUN apt-get update -qq && \
    apt-get install -y build-essential libpq-dev postgresql-client curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without 'development test' && bundle install

COPY . .

RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

EXPOSE 3000
CMD ["bundle", "exec", "thrust", "rails", "server", "-b", "0.0.0.0"]
