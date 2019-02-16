CC=g++
CFLAGS = -std=c++2a -g -Wall
TARGET = ORDER_VECTOR

all : $(TARGET)

$(TARGET): .main.o
	$(CC) $(CFLAGS) $^ -o $@
.main.o : main.cc
	$(CC) $(CFLAGS) -c $< -o $@

.PHONY : clean
clean:
	rm -f $(TARGET) *.o *.gch .*.o .*.gch

