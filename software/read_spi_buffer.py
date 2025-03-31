import spidev
import time

# Abra o dispositivo SPI
spi = spidev.SpiDev()
spi.open(1, 0)  # SPI 1, chip select 0

# Configurar a comunicação SPI
spi.max_speed_hz = 1000000
spi.mode = 0

# Número de bytes a serem lidos
num_bytes = 16

# Enviar um comando de leitura e ler 16 bytes (dependendo do dispositivo, o comando pode ser diferente ou não necessário)
response = spi.xfer2([0x00] * c)  # Envia 16 bytes zeros para ler 16 bytes de resposta

# Imprimir a resposta em hexadecimal
print("Resposta:", ' '.join(f'{byte:02X}' for byte in response))

spi.close()