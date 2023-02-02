# CNN on CUDA
Implementation of Convolutional Neural Network using CUDA. On testing with MNIST dataset for 50 epochs, accuracy of 97.22% was obtained with a GPU training time of about 650 seconds.

## Architecture
All tests performed on an Nvidia GeForce 840M GPU, running CUDA 8.0.61.

## Compiling and Execution
To compile just navigate to root and type `make`
Executable can be run using `./CNN`

## Data Size

Count of samples:
- Train Dataset $\textsf{train\_cnt} = 60000$
- Test Dataset $\textsf{test\_cnt} = 10000$

Floating-Point data:

- MNIST Train Input: $28 \times 28 \times \textsf{train\_cnt} = 47040000$
- MNIST Test Input: $28 \times 28 \times \textsf{test\_cnt} = 7840000$
- Convolution Layer `c1`
  - 6 kernels, per $5 \times 5$, total $5 \times 5 \times 6=150$
  - 6 bias, size: $6$
- Subsample Layer `s1`
  - one $4 \times 4$ weight matrix, total $4 \times 4 = 16$
  - one scalar bias, total $1$
- Full Connection Layer `f`
  - weight matrix $6 \times 6 \times 6 \times 10 = 2160$
  - bias vector $10$
- MNIST Train Output: $10 \times \textsf{train\_cnt} = 600000$
- MNIST Test Output: $10 \times \textsf{test\_cnt} = 100000$

Enumerate data:
- MNIST Train Labels: $\textsf{train\_cnt}$
- MNIST Test Labels: $\textsf{test\_cnt}$

## Data Dump

Dump data to plain text files:

- `model_params.txt`:
  - format: vector of float, only one line
  - content: post-trained `weight` matrix and `bias` vector of each layer
  - size: $150 + 6 + 16 + 1 + 2160 + 10=2343$
- `train_input_params.txt`:
  - format: vector of float, only one line
  - content: image pixels of train dataset
  - size: $28 \times 28 \times \textsf{train\_cnt} = 47040000$
- `test_input_params.txt`:
  - format: vector of float, only one line
  - content: image pixels of teset dataset
  - size: $28 \times 28 \times \textsf{test\_cnt} = 7840000$
- `train_expected_results.txt` (\*not dumped)
  - format: vector of float, only one line
  - content: output hidden vector of full-conn layer, probability of each label
  - size: $10 \times \textsf{train\_cnt} = 600000$
- `test_expected_results.txt`
  - format: vector of float, only one line
  - content: output hidden vector of full-conn layer, probability of each label
  - size: $10 \times \textsf{test\_cnt} = 100000$