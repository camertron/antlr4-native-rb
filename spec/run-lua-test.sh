#! /bin/bash

antlr_version=$(bundle exec ruby -Ilib -rantlr4-native -e "puts Antlr4Native::Generator::ANTLR_VERSION")
docker build --build-arg ANTLR_VERSION="${antlr_version}" -t antlr4-native-rb:latest .
docker run -t antlr4-native-rb:latest bundle exec ruby parse_test.rb
