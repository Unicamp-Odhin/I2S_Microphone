import spidev
import wave
import time
import struct

SPI_BUS = 1
SPI_CS = 0
SPI_MAX_SPEED = 400000
SPI_MODE = 0
CHUNK_SIZE = 4096
DURATION = 20  # segundos
SAMPLE_RATE = 44100  # Hz (taxa de amostragem do áudio)
BITS_PER_SAMPLE = 16  # 16 bits por amostra
NUM_CHANNELS = 1  # Mono
OUTPUT_FILENAME = "output.wav"

spi = spidev.SpiDev()
spi.open(SPI_BUS, SPI_CS)
spi.max_speed_hz = SPI_MAX_SPEED
spi.mode = SPI_MODE

start_time = time.time()
data = bytearray()

while time.time() - start_time < DURATION:
    response = spi.xfer2([0x00] * CHUNK_SIZE)
    data.extend(response)

spi.close()

# Converte os dados para formato PCM 16-bit
pcm_data = bytearray()
for i in range(0, len(data) - 1, 2):
    sample = data[i] | (data[i + 1] << 8)
    sample = struct.pack('<h', sample)  # Formato little-endian signed 16-bit
    pcm_data.extend(sample)

# Salva como arquivo WAV
with wave.open(OUTPUT_FILENAME, 'w') as wav_file:
    wav_file.setnchannels(NUM_CHANNELS)
    wav_file.setsampwidth(BITS_PER_SAMPLE // 8)
    wav_file.setframerate(SAMPLE_RATE)
    wav_file.writeframes(pcm_data)

print(f"Áudio salvo em '{OUTPUT_FILENAME}' com sucesso!")
