#define USE_MNIST_LOADER
#define MNIST_DOUBLE
#include "mnist.h"
#include "layer.h"
#include "dump.h"

#include <cuda.h>
#include <cstdio>
#include <time.h>

static mnist_data *train_set, *test_set;
static unsigned int train_cnt, test_cnt;

// Define layers of CNN
static Layer l_input = Layer(0, 0, 28*28);
static Layer l_c1 = Layer(5*5, 6, 24*24*6);
static Layer l_s1 = Layer(4*4, 1, 6*6*6);
static Layer l_f = Layer(6*6*6, 10, 10);

static void learn();
static unsigned int classify(double data[28][28], FileWriter * const debug);
static void test(const char *result_name, const char *debug_name);
static double forward_pass(double data[28][28], FileWriter * const debug);
static double back_pass();

static inline void loaddata()
{
	mnist_load("data/train-images.idx3-ubyte", "data/train-labels.idx1-ubyte",
		&train_set, &train_cnt);
	mnist_load("data/t10k-images.idx3-ubyte", "data/t10k-labels.idx1-ubyte",
		&test_set, &test_cnt);
	fprintf(stderr, "train_cnt = %d, test_cnt = %d\n", train_cnt, test_cnt);
	// dump input params
	FileWriter train_writer("train_input_params.txt");
	for (int i = 0; i < train_cnt; i++) {
		train_writer.writeDouble((double *)train_set[i].data, 28 * 28);
	}
	FileWriter test_writer("test_input_params.txt");
	for (int i = 0; i < test_cnt; i++) {
		test_writer.writeDouble((double *)test_set[i].data, 28 * 28);
	}
}

static inline void dump_model_layer(const int size, const float *d_data, FileWriter& writer) {
	static float h_buf[8192];
	cudaMemcpy(h_buf, d_data, size * sizeof(float), cudaMemcpyDeviceToHost);
	writer.writeFloat(h_buf, size);
}

int main(int argc, const  char **argv)
{
	srand(time(NULL));

	CUresult err = cuInit(0);
	if (err != CUDA_SUCCESS) {
		fprintf(stderr, "CUDA initialisation failed with error code - %d\n", err);
		return 1;
	}

	loaddata();
	learn();

	// dump model params
	FileWriter model_writer("model_params.txt");
	// conv layer weight
	dump_model_layer(l_c1.M * l_c1.N, l_c1.weight, model_writer);
	// conv layer bias
	dump_model_layer(l_c1.N, l_c1.bias, model_writer);
	// subsample layer weight
	dump_model_layer(l_s1.M * l_s1.N, l_s1.weight, model_writer);
	// subsample layer bias
	dump_model_layer(l_s1.N, l_s1.bias, model_writer);
	// full conn layer weight
	dump_model_layer(l_f.M * l_f.N, l_f.weight, model_writer);
	// full conn layer bias
	dump_model_layer(l_f.N, l_f.bias, model_writer);

	test("test_expected_results.txt", "debug");
	// test("test2_expected_results.txt", "debug2"); // re-produce to ensure the result is certain

	return 0;
}

// Forward propagation of a single row in dataset
static double forward_pass(double data[28][28], FileWriter * const debug)
{
	float input[28][28];

	for (int i = 0; i < 28; ++i) {
		for (int j = 0; j < 28; ++j) {
			input[i][j] = data[i][j];
		}
	}

	l_input.clear();
	l_c1.clear();
	l_s1.clear();
	l_f.clear();

	clock_t start, end;
	start = clock();

	l_input.setOutput((float *)input);
	if (debug != NULL) {
		debug->writeLine("Input:");
		dump_model_layer(l_input.O, l_input.output, *debug);
	}

	fp_preact_c1<<<64, 64>>>((float (*)[28])l_input.output, (float (*)[24][24])l_c1.preact, (float (*)[5][5])l_c1.weight);
	if (debug != NULL) {
		debug->writeLine("Conv-Kern:");
		dump_model_layer(l_c1.O, l_c1.preact, *debug);
	}
	fp_bias_c1<<<64, 64>>>((float (*)[24][24])l_c1.preact, l_c1.bias);
	if (debug != NULL) {
		debug->writeLine("Conv-Bias:");
		dump_model_layer(l_c1.O, l_c1.preact, *debug);
	}
	apply_step_function<<<64, 64>>>(l_c1.preact, l_c1.output, l_c1.O);
	if (debug != NULL) {
		debug->writeLine("Conv-Actv:");
		dump_model_layer(l_c1.O, l_c1.output, *debug);
	}

	fp_preact_s1<<<64, 64>>>((float (*)[24][24])l_c1.output, (float (*)[6][6])l_s1.preact, (float (*)[4][4])l_s1.weight);
	if (debug != NULL) {
		debug->writeLine("Samp-WSum:");
		dump_model_layer(l_s1.O, l_s1.preact, *debug);
	}
	fp_bias_s1<<<64, 64>>>((float (*)[6][6])l_s1.preact, l_s1.bias);
	if (debug != NULL) {
		debug->writeLine("Samp-Bias:");
		dump_model_layer(l_s1.O, l_s1.preact, *debug);
	}
	apply_step_function<<<64, 64>>>(l_s1.preact, l_s1.output, l_s1.O);
	if (debug != NULL) {
		debug->writeLine("Samp-Actv:");
		dump_model_layer(l_s1.O, l_s1.output, *debug);
	}

	fp_preact_f<<<64, 64>>>((float (*)[6][6])l_s1.output, l_f.preact, (float (*)[6][6][6])l_f.weight);
	if (debug != NULL) {
		debug->writeLine("Full-Conn:");
		dump_model_layer(l_f.O, l_f.preact, *debug);
	}
	fp_bias_f<<<64, 64>>>(l_f.preact, l_f.bias);
	if (debug != NULL) {
		debug->writeLine("Full-Bias:");
		dump_model_layer(l_f.O, l_f.preact, *debug);
	}
	apply_step_function<<<64, 64>>>(l_f.preact, l_f.output, l_f.O);
	if (debug != NULL) {
		debug->writeLine("Full-Actv:");
		dump_model_layer(l_f.O, l_f.output, *debug);
	}
	
	end = clock();
	return ((double) (end - start)) / CLOCKS_PER_SEC;
}

// Back propagation to update weights
static double back_pass()
{
	clock_t start, end;

	start = clock();

	bp_weight_f<<<64, 64>>>((float (*)[6][6][6])l_f.d_weight, l_f.d_preact, (float (*)[6][6])l_s1.output);
	bp_bias_f<<<64, 64>>>(l_f.bias, l_f.d_preact);

	bp_output_s1<<<64, 64>>>((float (*)[6][6])l_s1.d_output, (float (*)[6][6][6])l_f.weight, l_f.d_preact);
	bp_preact_s1<<<64, 64>>>((float (*)[6][6])l_s1.d_preact, (float (*)[6][6])l_s1.d_output, (float (*)[6][6])l_s1.preact);
	bp_weight_s1<<<64, 64>>>((float (*)[4][4])l_s1.d_weight, (float (*)[6][6])l_s1.d_preact, (float (*)[24][24])l_c1.output);
	bp_bias_s1<<<64, 64>>>(l_s1.bias, (float (*)[6][6])l_s1.d_preact);

	bp_output_c1<<<64, 64>>>((float (*)[24][24])l_c1.d_output, (float (*)[4][4])l_s1.weight, (float (*)[6][6])l_s1.d_preact);
	bp_preact_c1<<<64, 64>>>((float (*)[24][24])l_c1.d_preact, (float (*)[24][24])l_c1.d_output, (float (*)[24][24])l_c1.preact);
	bp_weight_c1<<<64, 64>>>((float (*)[5][5])l_c1.d_weight, (float (*)[24][24])l_c1.d_preact, (float (*)[28])l_input.output);
	bp_bias_c1<<<64, 64>>>(l_c1.bias, (float (*)[24][24])l_c1.d_preact);


	apply_grad<<<64, 64>>>(l_f.weight, l_f.d_weight, l_f.M * l_f.N);
	apply_grad<<<64, 64>>>(l_s1.weight, l_s1.d_weight, l_s1.M * l_s1.N);
	apply_grad<<<64, 64>>>(l_c1.weight, l_c1.d_weight, l_c1.M * l_c1.N);

	end = clock();
	return ((double) (end - start)) / CLOCKS_PER_SEC;
}

// Unfold the input layer
static void unfold_input(double input[28][28], double unfolded[24*24][5*5])
{
	int a = 0;
	(void)unfold_input;

	for (int i = 0; i < 2; ++i)
		for (int j = 0; j < 2; ++j) {
			int b = 0;
			for (int x = i; x < i + 2; ++x)
				for (int y = j; y < j+2; ++y)
					unfolded[a][b++] = input[x][y];
			a++;
		}
}

static void learn()
{
	static cublasHandle_t blas;
	cublasCreate(&blas);

	float err;
	int iter = 50;
	
	double time_taken = 0.0;

	fprintf(stdout ,"Learning\n");

	while (iter < 0 || iter-- > 0) {
		err = 0.0f;

		for (int i = 0; i < train_cnt; ++i) {
			float tmp_err;

			time_taken += forward_pass(train_set[i].data, NULL);

			l_f.bp_clear();
			l_s1.bp_clear();
			l_c1.bp_clear();

			// Euclid distance of train_set[i]
			makeError<<<10, 1>>>(l_f.d_preact, l_f.output, train_set[i].label, 10);
			cublasSnrm2(blas, 10, l_f.d_preact, 1, &tmp_err);
			err += tmp_err;

			time_taken += back_pass();
		}

		err /= train_cnt;
		fprintf(stdout, "error: %e, time_on_gpu: %lf\n", err, time_taken);

		if (err < threshold) {
			fprintf(stdout, "Training complete, error less than threshold\n\n");
			break;
		}

	}
	
	fprintf(stdout, "\n Time - %lf\n", time_taken);
}


// Returns label of given data (0-9)
static unsigned int classify(double data[28][28], FileWriter * const debug)
{
	float res[10];

	forward_pass(data, debug);

	unsigned int max = 0;

	cudaMemcpy(res, l_f.output, sizeof(float) * 10, cudaMemcpyDeviceToHost);

	for (int i = 1; i < 10; ++i) {
		if (res[max] < res[i]) {
			max = i;
		}
	}

	return max;
}

// Perform forward propagation of test data
static void test(const char *result_name, const char *debug_name)
{
	FileWriter result_writer(result_name);
	int error = 0;
	char buf[128];

	for (int i = 0; i < test_cnt; ++i) {
		sprintf(buf, "%s_%d.txt", debug_name, i);
		FileWriter *debug_writer = NULL;
		if (i < 10) {
			debug_writer = new FileWriter(buf);
		}
		if (classify(test_set[i].data, debug_writer) != test_set[i].label) {
			++error;
		}
		if (debug_writer != NULL) {
			delete debug_writer;
		}
		dump_model_layer(10, l_f.output, result_writer);
	}

	fprintf(stdout, "Error Rate: %.2lf%%\n",
		double(error) / double(test_cnt) * 100.0);
}
