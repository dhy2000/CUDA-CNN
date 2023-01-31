all:
	nvcc -lcuda *.cu -o CNN -Wno-deprecated-gpu-targets

run:
	./CNN
clean:
	rm CNN
