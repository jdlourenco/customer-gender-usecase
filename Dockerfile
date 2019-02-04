FROM ruby:2.4.3

RUN mkdir /app

EXPOSE 4567

COPY Gemfile /app
COPY Gemfile.lock /app
COPY gender_service.rb /app

WORKDIR app
RUN bundle install

CMD ["bundle", "exec", "ruby", "gender_service.rb"]