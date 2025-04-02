import wave
import struct
import sys

# Configurações do arquivo WAV
SAMPLE_RATE = 48828  # Frequência de amostragem (em Hz)
NUM_CHANNELS = 1     # Número de canais (1 = mono, 2 = estéreo)
SAMPLE_WIDTH = 2     # Largura de amostra (em bytes, 2 = 16 bits)
AMPLITUDE = 32767    # Amplitude máxima para 16 bits
LITTLE_ENDIAN = False  # Altere para False para usar big-endian

def wav_to_hex(input_file, output_file):
    with wave.open(input_file, 'r') as wav_file:
        num_channels = wav_file.getnchannels()
        sample_width = wav_file.getsampwidth()
        frame_rate = wav_file.getframerate()
        num_frames = wav_file.getnframes()

        print(f"Informações do arquivo WAV:")
        print(f"  Número de canais: {num_channels}")
        print(f"  Largura de amostra: {sample_width} bytes")
        print(f"  Frequência de amostragem: {frame_rate} Hz")
        print(f"  Número de quadros: {num_frames}")

        frames = wav_file.readframes(num_frames)
        audio_data = struct.unpack('<' + 'h' * (len(frames) // sample_width), frames)

    with open(output_file, 'w') as f:
        for sample in audio_data:
            if sample < 0:
                sample += 65536
            if LITTLE_ENDIAN:
                byte1 = sample & 0xFF
                byte2 = (sample >> 8) & 0xFF
            else:
                byte1 = (sample >> 8) & 0xFF
                byte2 = sample & 0xFF
            f.write(f"{byte1:02X}{byte2:02X}\n")

    print(f"Arquivo HEX gerado: {output_file}")

if __name__ == "__main__":
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    wav_to_hex(input_file, output_file)