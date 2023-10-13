FROM ruby:3.2
ARG ANTLR_VERSION

RUN apt-get update && apt-get install -y default-jre

WORKDIR /usr/src
COPY . .

WORKDIR /usr/src/spec/lua-parser-rb
RUN git clone https://github.com/lua/lua.git
RUN git clone https://github.com/antlr/antlr4 ext/lua_parser/antlr4-upstream
RUN cd ext/lua_parser/antlr4-upstream && git checkout ${ANTLR_VERSION}
RUN bundle install --jobs $(nproc) --retry 3
RUN bundle exec rake generate compile
