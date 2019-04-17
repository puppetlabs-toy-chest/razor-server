FROM jruby:9.1.5.0-alpine

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
# upgrade bundler and install gems
RUN gem install bundler && bundle install

COPY app.rb .
COPY config.yaml.docker .
COPY config.ru .
COPY shiro.ini .
COPY torquebox.rb .
COPY Rakefile .
COPY bin ./bin
RUN chmod +x bin/*
COPY brokers ./brokers
COPY db ./db
COPY hooks ./hooks
# this seems to be needed
COPY jars ./jars
COPY lib ./lib
COPY locales ./locales
COPY spec ./spec
COPY tasks ./tasks

RUN mv config.yaml.docker config.yaml \
    && mkdir -p /var/lib/razor/repo-store

# Install openssl so we can download from HTTPS (e.g. microkernel), plus
# libarchive (must be "-dev" so we can find the .so files).
RUN apk update && apk --update add openssl && apk --update add libarchive-dev

# For debugging.
RUN apk add vim

ENTRYPOINT ["/usr/src/app/bin/run-local"]
