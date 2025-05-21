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

//TODO: Para facilitar e tornar mais preciso a leitura dos dados, o código deveria ser capaz de resetar o buffer da fpga
//      e ler os dados em um intervalo de tempo

/*
    Os dados quando PAGE_SIZE = 4096 estava gerando um rotação dos bytes em períodos de ~1364, que 4096 / 3
    Exemplo:
        1.    AABBCC
        ....
        1365. CCBBAA
        ....
        2730. BBCCCC
        ...
    Por algum motivo quando PAGE_SIZE = 1024 * 3, isso não acontece, chuto que é por ser múltiplo de 3

    Dependo do valor do SPEED isso gera um deslocamento de uma certa quantidade de bits nos dados, mas com 
    o valor de 3MHz isso não acontece
*/

// Configuração do pino de reset
#define GPIO_NUMBER "44"
#define GPIO_PATH "/sys/class/gpio"
#define GPIO_EXPORT GPIO_PATH "/export"
#define GPIO_DIR_PATH GPIO_PATH "/gpio" GPIO_NUMBER
#define GPIO_DIR GPIO_DIR_PATH "/direction"
#define GPIO_VAL GPIO_DIR_PATH "/value"

// CONFIGURAÇÕES DO SISTEMA DE AQUISIÇÃO
#define READ_SIZE     (3 * 1024 * 1024)  // Quantidade total de bytes a serem lidos
#define PAGE_SIZE     (1024 * 3)    // Leitura por operação (múltiplo de 3)
#define MEMORY_SIZE   (128 * 1024)   // Capacidade da memória da FPGA
#define SAMPLE_RATE   6050          // Amostras por segundo
#define SAMPLE_SIZE   3             // Tamanho de cada amostra em bytes (24 bits)

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

static int gpio_set_direction(const char *direction) {
    return gpio_write(GPIO_DIR, direction);
}

static int gpio_set_value(int value) {
    return gpio_write(GPIO_VAL, value ? "1" : "0");
}

static int reset_fpga() {
    if (gpio_export() == -1) {
        fprintf(stderr, "Aviso: GPIO pode já estar exportado.\n");
    }

    usleep(100000); // 100ms

    if (gpio_set_direction("out") == -1)
        return 1;

    if (gpio_set_value(1) == -1)
        return 1;

    usleep(100000); // 100ms

    if (gpio_set_value(0) == -1)
        return 1;

    printf("GPIO %s resetado com sucesso.\n", GPIO_NUMBER);
    return 0;
}


static void pabort(const char *s) {
    perror(s);
    abort();
}

static void wait_for_buffer_fill() {
    double seconds = (double)MEMORY_SIZE / (SAMPLE_RATE * SAMPLE_SIZE);
    printf("Esperando %.2f segundos para encher o buffer...\n", seconds);
    usleep((useconds_t)(seconds * 1e6));
}

static void read_and_save(int fd, const char *filename) {
    FILE *out = fopen(filename, "w");
    if (!out)
        pabort("Erro ao abrir arquivo para escrita");

    size_t total_remaining = READ_SIZE;
    uint8_t *buffer = malloc(MEMORY_SIZE);
    if (!buffer)
        pabort("Erro de alocação");
    memset(buffer, 0, MEMORY_SIZE);

    while (total_remaining > 0) {
        wait_for_buffer_fill();

        size_t read_now = total_remaining > MEMORY_SIZE ? MEMORY_SIZE : total_remaining;
        size_t offset = 0;
        size_t remaining = read_now;

        // Leitura do SPI
        while (remaining > 0) {
            size_t chunk_size = remaining > PAGE_SIZE ? PAGE_SIZE : remaining;

            if (chunk_size % 2 != 0)
                chunk_size--;

            struct spi_ioc_transfer tr = {
                .tx_buf = 0,
                .rx_buf = (unsigned long)(buffer + offset),
                .len = chunk_size,
                .delay_usecs = DELAY,
                .speed_hz = SPEED,
                .bits_per_word = BITS_PER_WORD,
            };

            int ret = ioctl(fd, SPI_IOC_MESSAGE(1), &tr);
            if (ret < 1)
                pabort("Erro ao enviar mensagem SPI");

            offset += chunk_size;
            remaining -= chunk_size;
        }

        // Escrita no arquivo
        offset = 0;
        remaining = read_now;

        while (remaining > 0) {
            size_t chunk_size = remaining > PAGE_SIZE ? PAGE_SIZE : remaining;

            if (chunk_size % 2 != 0)
                chunk_size--;

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

int main(void) {
    int fd, ret;

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
    printf("Tamanho total a ler: %d KB\n", READ_SIZE / 1024);
    printf("Buffer de aquisição: %d KB\n", MEMORY_SIZE / 1024);
    printf("Amostras por segundo: %d, tamanho da amostra: %d bytes\n\n", SAMPLE_RATE, SAMPLE_SIZE);

    reset_fpga();
    read_and_save(fd, "dump.hex");

    close(fd);
    return 0;
}
