import spidev
import time
import pyaudio

SPI_BUS = 1
SPI_CS = 0
SPI_MAX_SPEED = 400000
SPI_MODE = 0
CHUNK_SIZE = 4096

CAPTURE_DURATION = 20  # Duração em segundos
SAMPLE_WIDTH = 2  # Cada amostra tem 2 bytes (16 bits)
CHANNELS = 1  # Áudio mono
SAMPLING_RATE = 44100  # Frequência de amostragem estimada (ajuste conforme necessário)

spi = spidev.SpiDev()
spi.open(SPI_BUS, SPI_CS)
spi.max_speed_hz = SPI_MAX_SPEED
spi.mode = SPI_MODE

# Configurar PyAudio para reprodução
p = pyaudio.PyAudio()
stream = p.open(format=p.get_format_from_width(SAMPLE_WIDTH),
                channels=CHANNELS,
                rate=SAMPLING_RATE,
                output=True)

start_time = time.time()

print("Capturando e reproduzindo áudio por 20 segundos...")

try:
    while time.time() - start_time < CAPTURE_DURATION:
        response = spi.xfer2([0x00] * CHUNK_SIZE)
        # Converter os dados para bytes e reproduzir
        audio_data = bytearray()
        for i in range(0, len(response) - 1, 2):  # Passa por pares de bytes
            sample = response[i] | (response[i + 1] << 8)
            audio_data.extend(sample.to_bytes(SAMPLE_WIDTH, byteorder='little', signed=True))
        stream.write(audio_data)
finally:
    spi.close()
    stream.stop_stream()
    stream.close()
    p.terminate()

print("Captura e reprodução finalizadas.")