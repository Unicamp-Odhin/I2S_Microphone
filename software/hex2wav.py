import wave
import sys
import struct
import os

# Configurações do arquivo WAV
SAMPLE_RATE = 48828  # Frequência de amostragem (em Hz)
NUM_CHANNELS = 1     # Número de canais (1 = mono, 2 = estéreo)
SAMPLE_WIDTH = 2     # Largura de amostra (em bytes, 2 = 16 bits)
AMPLITUDE = 32767    # Amplitude máxima para 16 bits
LITTLE_ENDIAN = True  # Altere para False para usar big-endian


def hex_to_wav(input_file, output_file):
    with open(input_file, 'r') as f:
        hex_lines = f.readlines()


    audio_data = []
    for line in hex_lines[:len(hex_lines) // 6]:
        line = line.strip()
        if len(line) == 4:
            byte1 = int(line[:2], 16)
            byte2 = int(line[2:], 16)
            if LITTLE_ENDIAN:
                sample = (byte2 << 8) | byte1
            else:
                sample = (byte1 << 8) | byte2
            if sample >= 32768:
                sample -= 65536
            audio_data.append(sample)

    with wave.open(output_file, 'w') as wav_file:
        wav_file.setnchannels(NUM_CHANNELS)
        wav_file.setsampwidth(SAMPLE_WIDTH)
        wav_file.setframerate(SAMPLE_RATE)

        for sample in audio_data:
            wav_file.writeframes(struct.pack('<h', sample))  # '<h' = little-endian, 16 bits

    print(f"Arquivo WAV gerado: {output_file}")

# if __name__ == "__main__":
#     input_file = sys.argv[1]
#     output_file = input_file.replace(".hex", ".wav")
#     hex_to_wav(input_file, output_file)

if __name__ == "__main__":
#    for n in range(0, 1):
#        os.makedirs("wav", exist_ok=True)
#        input_file = "output.hex"
#        output_file = input_file.replace(".hex", ".wav").replace("hex/", "wav/")
#        hex_to_wav(input_file, output_file)