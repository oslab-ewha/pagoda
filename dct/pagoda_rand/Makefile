TARGET=dct
GPATH=/usr/local/cuda-7.5/bin
NVCC=$(GPATH)/nvcc
INC=/usr/local/cuda-7.5/samples/common/inc
CFLAGS=-O3 -w 
ARCH=sm_52
REG=32

.PHONY: default all clean

default: $(TARGET)
all: default

OBJECTS = $(patsubst %.cu, %.o, $(wildcard *.cu))

%.o: %.cu
	$(NVCC) $(CFLAGS)-I$(INC) -arch=$(ARCH) -maxrregcount $(REG) -dc $< -o $@

.PRECIOUS: $(TARGET) $(OBJECTS)

$(TARGET): $(OBJECTS)
	$(NVCC) $(CFLAGS)-I$(INC) -arch=$(ARCH) -maxrregcount $(REG) $(OBJECTS) -o $@

clean:
	-rm -f *.o
	-rm -f $(TARGET)
