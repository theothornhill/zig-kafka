OS := $(shell uname)

all: check_dependencies librdkafka run

check_dependencies:
ifeq ($(OS),Darwin)
    brew install curl-openssl cyrus-sasl
else ifeq ($(OS),Linux)
    sudo apt-get update
    sudo apt-get install -y libsasl2-dev libssl-dev libcurl4-openssl-dev
endif

librdkafka:
    cd c/librdkafka && ./configure

foo:
    LD_LIBRARY_PATH="$HOME/.guix-profile/lib:$LD_LIBRARY_PATH" zig build run

run:
    zig build run
