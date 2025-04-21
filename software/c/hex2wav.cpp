#include <complex.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

// Estrutura do cabeçalho WAV (44 bytes)
typedef struct {
    char riff[4];           // "RIFF"
    uint32_t file_size;     // Tamanho total do arquivo - 8
    char wave[4];           // "WAVE"
    char fmt[4];            // "fmt "
    uint32_t fmt_size;      // Tamanho do chunk fmt (16 para PCM)
    uint16_t audio_format;  // Formato de áudio (1 = PCM)
    uint16_t num_channels;  // Número de canais (1 = mono, 2 = stereo)
    uint32_t sample_rate;   // Taxa de amostragem (ex: 44100 Hz)
    uint32_t byte_rate;     // Bytes por segundo (sample_rate * num_channels * bits_per_sample/8)
    uint16_t block_align;   // Alinhamento (num_channels * bits_per_sample/8)
    uint16_t bits_per_sample; // Bits por amostra (ex: 16, 24)
    char data[4];           // "data"
    uint32_t data_size;     // Tamanho dos dados de amostra
} WavHeader;

#define FREQUENCY_SINC 127
#define CONFIDENCE_LEVEL 3

typedef struct {
    const char *pattern1;
    const char *pattern2;
    int conversion_type;
} ConversionRule;

ConversionRule rules[] = {
    {"00AAFF", "00557F",0},
    {"00FFAA", "007FD5", 1},
    {"AA00FF", "55007F", 2},
    {"AAFF00", "557F80", 3},
    {"FF00AA", "7F8055", 4},
    {"FFAA00", "7FD500", 5}
};

#define NUM_RULES (sizeof(rules) / sizeof(rules[0]))


int find_init_sinc(FILE *input_file){
    char line[16];
    int line_number = 0;
    int init_sinc = -1;

    int counter_check = 0;

    while (fgets(line, sizeof(line), input_file)) {
        line_number++;

        if (strstr(line, "FF00AA") != NULL || strstr(line, "00FFAA") != NULL ||
            strstr(line, "FFAA00") != NULL || strstr(line, "00AAFF") != NULL ||
            strstr(line, "AAFF00") != NULL || strstr(line, "AA00FF") != NULL) {
            
            if (counter_check == 0) {
                init_sinc = line_number;
                counter_check++;
            }
            else if (counter_check < CONFIDENCE_LEVEL) {
                if (line_number - init_sinc == FREQUENCY_SINC) {
                    init_sinc = line_number;
                    counter_check++;
                }
                else {
                    counter_check = 0;
                    init_sinc = -1;
                }
            }
            if (counter_check == CONFIDENCE_LEVEL) {
                return init_sinc - (CONFIDENCE_LEVEL - 1) * FREQUENCY_SINC;
            }
        }
    }

    return -1;  // Retorna o número da linha ou -1 se não encontrar o marcador
}


// Função para pré-processar a linha e decidir o tipo
int type_line(char* line) {
    int type = -1;
    for (int i = 0; i < NUM_RULES; i++) {
        if (strcmp(line, rules[i].pattern1) == 0 || strcmp(line, rules[i].pattern2) == 0) {
            type = rules[i].conversion_type;
            break;
        }
    }
    return type;
}

// Função para decodificar a linha com base no tipo
uint32_t decoder(char* line, int type) {
    uint32_t byte1 = (strtol(line, NULL, 16) >> 16) & 0xFF;
    uint32_t byte2 = (strtol(line, NULL, 16) >> 8) & 0xFF;
    uint32_t byte3 = (strtol(line, NULL, 16)) & 0xFF;
    uint32_t sample;

    switch (type) {
        case 0: // 00AAFF 
            sample = (byte2 << 16) | (byte3 << 8) | byte1;
            break;
        case 1: // 00FFAA
            sample = (byte3 << 16) | (byte2 << 3) | byte1;
            break;
        case 2: // AA00FF
            sample = (byte1 << 16) | (byte3 << 8) | byte2;
            break;
        case 3: // AAFF00
            sample = (byte1 << 16) | (byte2 << 8) | byte3;
            break;
        case 4: // FF00AA
            sample = (byte2 << 16) | (byte3 << 8) | byte1;
            break;
        case 5: // FFAA00
            sample = (byte2 << 16) | (byte1 << 8) | byte3;
            break;
        default:
            sample = (byte2 << 16) | (byte3 << 8) | byte1; // Default case
            break;
    }

    return sample;
}

int main() {
    const char *input_filename = "dump.hex";
    const char *output_filename = "dump.wav";

    const uint32_t sample_rate = 24414 / (4);
    const uint16_t num_channels = 1;      // Mono
    const uint16_t bits_per_sample = 24;  // 32 bits por amostra
    const uint16_t sample_width = bits_per_sample / 8;

    FILE *input_file = fopen(input_filename, "r");
    if (!input_file) {
        perror("Erro ao abrir arquivo de entrada");
        return 1;
    }

    uint32_t num_samples = 0;
    char line[16];
    while (fgets(line, sizeof(line), input_file)) {
        if (strstr(line, "000000") == NULL) {
            num_samples++;
        }
    }
    rewind(input_file);

    uint32_t data_size = num_samples * num_channels * sample_width;

    // Criar cabeçalho WAV
    WavHeader header;
    memcpy(header.riff, "RIFF", 4);
    header.file_size = 36 + data_size;
    memcpy(header.wave, "WAVE", 4);
    memcpy(header.fmt, "fmt ", 4);
    header.fmt_size = 16;
    header.audio_format = 1; // PCM
    header.num_channels = num_channels;
    header.sample_rate = sample_rate;
    header.byte_rate = sample_rate * num_channels * sample_width;
    header.block_align = num_channels * sample_width;
    header.bits_per_sample = bits_per_sample;
    memcpy(header.data, "data", 4);
    header.data_size = data_size;

    FILE *output_file = fopen(output_filename, "wb");
    if (!output_file) {
        perror("Erro ao criar arquivo WAV");
        fclose(input_file);
        return 1;
    }

    fwrite(&header, sizeof(WavHeader), 1, output_file);
    
    int type = -1; // default
    int init_sinc = find_init_sinc(input_file);
    if (init_sinc == -1) {
        printf("Erro: Não foi possível encontrar o marcador de inicialização.\n");
    } else {
        fseek(input_file, (init_sinc - 1) * 7, SEEK_SET); // Ajuste para o início do arquivo
        fgets(line, sizeof(line), input_file);
        line[strcspn(line, "\n")] = '\0';
        type = type_line(line);
        printf("init_sinc: %d, type: %d\n", init_sinc, type);
    }



    int counter = 1;
    while (fgets(line, sizeof(line), input_file)) {
        if (strstr(line, "000000") == NULL) {
            line[strcspn(line, "\n")] = '\0';
            
            int tmp = counter;
            if (counter % FREQUENCY_SINC == 0){    
                type = type_line(line);
                while (type == -1){
                    fgets(line, sizeof(line), input_file);
                    line[strcspn(line, "\n")] = '\0';
                    type = type_line(line);
                    counter = 0;
                    printf("deu merda\n");
                }
            } else {
                uint32_t sample = decoder(line, type);  
                fwrite(&sample, sample_width, 1, output_file);
            }
        }
        counter++;
    }

    fclose(input_file);
    fclose(output_file);

    printf("Arquivo WAV gerado com sucesso: %s\n", output_filename);
    printf("Número de amostras: %u\n", num_samples);
    printf("Taxa de amostragem: %u Hz\n", sample_rate);
    printf("Bits por amostra: %u\n", bits_per_sample);

    return 0;
}
