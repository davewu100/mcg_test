CC = gcc
CFLAGS = -Wall -O2

TARGETS = alloc readstats

all: $(TARGETS)

alloc: alloc.c
	$(CC) $(CFLAGS) -o $@ $<

readstats: readstats.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f $(TARGETS)

.PHONY: all clean


