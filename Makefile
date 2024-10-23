all: librdkafka run

librdkafka:
	cd c/librdkafka && ./configure

foo:
	LD_LIBRARY_PATH="$HOME/.guix-profile/lib:$LD_LIBRARY_PATH" zig build run

run:
	zig build run
