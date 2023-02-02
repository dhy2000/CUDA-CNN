#include "dump.h"

FileWriter::FileWriter(const char *filename)
    : filename(filename), fp(fopen(filename, "w")), print_flag(false), count(0) {
}

FileWriter::~FileWriter() {
    fclose(fp);
    fp = NULL;
    fprintf(stderr, "[FileWriter] written %d values to file %s.\n", this->count, this->filename.c_str());
}

void FileWriter::writeFloat(const float *data, const int size) {
    for (int i = 0; i < size; i++) {
        if (this->print_flag)
            fputc('\t', this->fp);
        fprintf(this->fp, "%f", data[i]);
        this->print_flag = true;
        this->count++;
    }
}

void FileWriter::writeDouble(const double *data, const int size) {
    for (int i = 0; i < size; i++) {
        if (this->print_flag)
            fputc('\t', this->fp);
        fprintf(this->fp, "%f", data[i]);
        this->print_flag = true;
        this->count++;
    }
}

void FileWriter::writeInteger(const int *data, const int size) {
    for (int i = 0; i < size; i++) {
        if (this->print_flag)
            fputc('\t', this->fp);
        fprintf(this->fp, "%d", data[i]);
        this->print_flag = true;
        this->count++;
    }
}