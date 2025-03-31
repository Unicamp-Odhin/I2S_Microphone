#include <stdint.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/spi/spidev.h>

#define DEVICE "/dev/spidev1.0"
#define DELAY 0
#define READ_SIZE 32  // Número de bytes que queremos ler (ajuste conforme necessário)

// Variáveis globais
static uint32_t SPEED = 500000;
static uint8_t BITS_PER_WORD = 8;
static uint8_t MODE = 0;

// Função de erro
static void pabort(const char *s)
{
    perror(s);
    abort();
}

// Função de dump em hexadecimal
static void hex_dump(const void *src, size_t length)
{
    const unsigned char *address = src;
    size_t i;

    for (i = 0; i < length; i++) {
        if (i % 16 == 0) printf("%08X  ", (unsigned int)i);
        printf("%02X ", address[i]);
        if ((i + 1) % 16 == 0) printf("\n");
    }
    if (i % 16 != 0) printf("\n");
}

// Função que lê um número fixo de bytes
static void read_fixed_bytes(int fd)
{
    int ret;
    uint8_t rx[READ_SIZE] = {0};
    struct spi_ioc_transfer tr = {
        .tx_buf = 0,
        .rx_buf = (unsigned long)rx,
        .len = READ_SIZE,
        .delay_usecs = DELAY,
        .speed_hz = SPEED,
        .bits_per_word = BITS_PER_WORD,
    };

    ret = ioctl(fd, SPI_IOC_MESSAGE(1), &tr);
    if (ret < 1)
        pabort("Erro ao enviar mensagem SPI");

    printf("Dados recebidos:\n");
    hex_dump(rx, READ_SIZE);
}

int main(void)
{
    int fd, ret;

    fd = open(DEVICE, O_RDWR);
    if (fd < 0)
        pabort("Não foi possível abrir o dispositivo SPI");

    // Configurações do modo SPI
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

    read_fixed_bytes(fd);

    close(fd);

    return 0;
}
