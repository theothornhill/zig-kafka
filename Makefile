build:
	guix build zig-kafka --with-source=$$(git rev-parse --show-toplevel)
