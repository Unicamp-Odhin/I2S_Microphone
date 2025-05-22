#include <stdint.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/spi/spidev.h>
#include <time.h>

#define DEVICE "/dev/spidev1.0"
#define DELAY  9

// Configuração do pino de reset
#define GPIO_NUMBER "50"
#define GPIO_PATH "/sys/class/gpio"
#define GPIO_EXPORT GPIO_PATH "/export"
#define GPIO_UNEXPORT GPIO_PATH "/unexport"
#define GPIO_DIR_PATH GPIO_PATH "/gpio" GPIO_NUMBER
#define GPIO_DIR GPIO_DIR_PATH "/direction"
#define GPIO_VAL GPIO_DIR_PATH "/value"

// CONFIGURAÇÕES DO SISTEMA DE AQUISIÇÃO
#define READ_TIME  5                 // Tempo em segundos de leitura
#define PAGE_SIZE     (1024 * 3)     // Leitura por operação (múltiplo de 3)
#define MEMORY_SIZE   (64 * 1024)   // Capacidade da memória da FPGA
#define SAMPLE_RATE   12207          // Amostras por segundo
#define SAMPLE_SIZE   3              // Tamanho de cada amostra em bytes (24 bits)
#define READ_SIZE (SAMPLE_RATE * SAMPLE_SIZE * READ_TIME)


static uint32_t SPEED = 3000000;
static uint8_t BITS_PER_WORD = 8;
static uint8_t MODE = 0;

static int gpio_write(const char *path, const char *value) {
    int fd = open(path, O_WRONLY);
    if (fd == -1) {
        perror(path);
        return -1;
    }

    if (write(fd, value, strlen(value)) == -1) {
        perror(path);
        close(fd);
        return -1;
    }

    close(fd);
    return 0;
}

static int gpio_export() {
    return gpio_write(GPIO_EXPORT, GPIO_NUMBER);
}

static int gpio_unexport() {
    return gpio_write(GPIO_UNEXPORT, GPIO_NUMBER);
}


static int gpio_set_direction(const char *direction) {
    return gpio_write(GPIO_DIR, direction);
}

static int gpio_set_value(int value) {
    return gpio_write(GPIO_VAL, value ? "1" : "0");
}

static int reset_fpga() {
    if (gpio_export() == -1) {
        fprintf(stderr, "\033[1;33mAviso: GPIO pode já estar exportado.\033[0m\n");
    }

    usleep(100000); // 100ms

    if (gpio_set_direction("out") == -1)
        return 1;

    if (gpio_set_value(1) == -1)
        return 1;

    usleep(100000); // 100ms
    
    if (gpio_set_value(0) == -1)
        return 1;
    
    usleep(100000); // 100ms

    printf("GPIO %s resetado com sucesso.\n", GPIO_NUMBER);
    return 0;
}

static void pabort(const char *s) {
    perror(s);
    abort();
}

static void read_and_save(int fd, const char *filename, size_t total_remaining) {
    FILE *out = fopen(filename, "w");
    if (!out)
        pabort("Erro ao abrir arquivo para escrita");

    uint8_t *buffer = malloc(MEMORY_SIZE);
    if (!buffer) 
        pabort("Erro de alocação");
    memset(buffer, 0, MEMORY_SIZE);

    while (total_remaining > 0) {
        size_t read_now = total_remaining > MEMORY_SIZE ? MEMORY_SIZE : total_remaining;
        double wait_seconds = (double)read_now / (SAMPLE_RATE * SAMPLE_SIZE);

        printf("\nAguardando %.2f segundos para adquirir %zu bytes...\n", wait_seconds, read_now);
        usleep((useconds_t)(wait_seconds * 1e6));

        size_t offset = 0;
        size_t remaining = read_now;

        // Leitura SPI por blocos de PAGE_SIZE
        while (remaining > 0) {
            size_t chunk_size = remaining > PAGE_SIZE ? PAGE_SIZE : remaining;
            if (chunk_size < SAMPLE_SIZE) break;
            chunk_size -= (chunk_size % SAMPLE_SIZE);

            struct spi_ioc_transfer tr = {
                .tx_buf = 0,
                .rx_buf = (unsigned long)(buffer + offset),
                .len = chunk_size,
                .delay_usecs = DELAY,
                .speed_hz = SPEED,
                .bits_per_word = BITS_PER_WORD,
            };

            if (ioctl(fd, SPI_IOC_MESSAGE(1), &tr) < 1) {
                pabort("Erro ao enviar mensagem SPI");
            }

            offset += chunk_size;
            remaining -= chunk_size;
        }

        // Escrita no arquivo
        offset = 0;
        remaining = read_now;

        while (remaining > 0) {
            size_t chunk_size = remaining > PAGE_SIZE ? PAGE_SIZE : remaining;
            if (chunk_size < SAMPLE_SIZE) break;
            chunk_size -= (chunk_size % SAMPLE_SIZE);

            for (size_t i = 0; i + 2 < chunk_size; i += 3) {
                uint32_t sample = (buffer[offset + i] |
                                  (buffer[offset + i + 1] << 8) |
                                  (buffer[offset + i + 2] << 16)) & 0x00FFFFFF;
                fprintf(out, "%06X\n", sample);
            }

            offset += chunk_size;
            remaining -= chunk_size;
        }

        total_remaining -= read_now;
    }

    free(buffer);
    fclose(out);
}


int main(int argc, char *argv[]) {
    int fd, ret;
    const char *output_file = "dump.hex";
    int read_time = READ_TIME;

    // Parse command line arguments
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--name") == 0 && i + 1 < argc) {
            output_file = argv[++i];
        } else if (strcmp(argv[i], "--time") == 0 && i + 1 < argc) {
            read_time = atoi(argv[++i]);
            if (read_time <= 0) {
                fprintf(stderr, "Valor inválido para --time\n");
                exit(EXIT_FAILURE);
            }
        }
    }

    size_t read_size = (SAMPLE_RATE * SAMPLE_SIZE * read_time);

    fd = open(DEVICE, O_RDWR);
    if (fd < 0)
        pabort("Não foi possível abrir o dispositivo SPI");

    ret = ioctl(fd, SPI_IOC_WR_MODE, &MODE);
    if (ret == -1)
        pabort("Não foi possível definir o modo SPI");

    ret = ioctl(fd, SPI_IOC_WR_BITS_PER_WORD, &BITS_PER_WORD);
    if (ret == -1)
        pabort("Não foi possível definir os bits por palavra");

    ret = ioctl(fd, SPI_IOC_WR_MAX_SPEED_HZ, &SPEED);
    if (ret == -1)
        pabort("Não foi possível definir a velocidade SPI");

    printf("Dispositivo: %s\n", DEVICE);
    printf("Modo SPI: %d\n", MODE);
    printf("Bits por palavra: %d\n", BITS_PER_WORD);
    printf("Velocidade máxima: %d Hz\n", SPEED);
    printf("Tamanho total a ler: %d KB\n", (int)read_size / 1024);
    printf("Buffer de aquisição: %d KB\n", MEMORY_SIZE / 1024);
    printf("Amostras por segundo: %d, tamanho da amostra: %d bytes\n\n", SAMPLE_RATE, SAMPLE_SIZE);

    reset_fpga();
    read_and_save(fd, output_file, read_size);
    gpio_unexport();

    close(fd);
    return 0;
}