all:
	nvcc -lcuda -lcublas *.cu *.cc -o CNN -Wno-deprecated-gpu-targets

run:
	./CNN
clean:
	rm CNN
