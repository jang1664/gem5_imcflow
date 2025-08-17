CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -O2
TARGET = test_imcflow
SOURCE = test_imcflow.c

# For gem5 X86 target
X86_TARGET = $(TARGET)_x86
X86_CC = x86_64-linux-gnu-gcc

# Build native version (for testing address calculations)
$(TARGET): $(SOURCE)
	$(CC) $(CFLAGS) -o $@ $<

# Build X86 version for gem5
$(X86_TARGET): $(SOURCE)
	$(X86_CC) $(CFLAGS) -static -o $@ $<

# Build both versions
all: $(TARGET) $(X86_TARGET)

# Clean build artifacts
clean:
	rm -f $(TARGET) $(X86_TARGET)

# Run native test (just for address verification)
test: $(TARGET)
	./$(TARGET)

# Show build info
info:
	@echo "Targets:"
	@echo "  $(TARGET)     - Native build for testing"
	@echo "  $(X86_TARGET) - X86 build for gem5"
	@echo "  all          - Build both targets"
	@echo "  clean        - Remove build artifacts"
	@echo "  test         - Run native test"

.PHONY: all clean test info
