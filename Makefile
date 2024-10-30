OS := $(shell uname)

all: librdkafka run

# check_dependencies:
# ifeq ($(OS),Darwin)
# 		brew install curl-openssl cyrus-sasl
# else ifeq ($(OS),Linux)
# 		sudo apt-get update
# 		sudo apt-get install -y libsasl2-dev libssl-dev libcurl4-openssl-dev
# endif

librdkafka:
	cd c/librdkafka && ./configure --disable-zstd

run-fast:
	zig build run -Doptimize=ReleaseFast --summary all

run:
	zig build run -Doptimize=ReleaseSafe --summary all

test:
	zig build test --summary all
