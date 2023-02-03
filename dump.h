#ifndef DUMP_H
#define DUMP_H

#include <cstdio>
#include <string>

using std::string;

class FileWriter {
private:
    string filename;
    FILE *fp;
    bool print_flag;
    int count;
public:
    FileWriter(const char *filename);
    ~FileWriter();

    void writeFloat(const float *data, const int size);
    void writeDouble(const double *data, const int size);
    void writeInteger(const int *data, const int size);

    void writeLine(const string& s);
};


#endif