import wave
import sys
import struct
import os

# Configurações do arquivo WAV
SAMPLE_RATE = 48828 * 4  # Frequência de amostragem (em Hz)
NUM_CHANNELS = 1     # Número de canais (1 = mono, 2 = estéreo)
SAMPLE_WIDTH = 4     # Largura de amostra (em bytes, 2 = 16 bits)


def hex_to_wav(input_file, output_file):
    with open(input_file, 'r') as f:
        hex_lines = f.readlines()

    audio_data = []
    previous_line = '000000'
    for i in range(1, len(hex_lines), 1):
        line = hex_lines[i]
        if not '000000' in line and line != previous_line:
            previous_line = line
            line = line.strip()
            byte1 = int(line[:2], 24)
            byte2 = int(line[2:4], 24)
            byte3 = int(line[4:6], 24)
            sample =  (byte1 << 16) | (byte2 << 8) | byte3
            audio_data.append(sample)

    with wave.open(output_file, 'w') as wav_file:
        wav_file.setnchannels(NUM_CHANNELS)
        wav_file.setsampwidth(SAMPLE_WIDTH)
        wav_file.setframerate(SAMPLE_RATE)

        for sample in audio_data:
            wav_file.writeframes(struct.pack('<i', sample))

    print(f"Arquivo WAV gerado: {output_file}")

if __name__ == "__main__":
    input_file = sys.argv[1]
    output_file = input_file.replace(".hex", ".wav")
    hex_to_wav(input_file, output_file)