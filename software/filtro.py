import numpy as np
import matplotlib.pyplot as plt
import wave

def read_wav(file_path):
    with wave.open(file_path, 'r') as wav_file:
        n_channels = wav_file.getnchannels()
        sample_width = wav_file.getsampwidth()
        frame_rate = wav_file.getframerate()
        n_frames = wav_file.getnframes()
        
        
        frames = wav_file.readframes(n_frames)
        signal = np.frombuffer(frames, dtype=np.int16)
        
        if n_channels > 1:
            signal = signal[::n_channels]
        
        time = np.linspace(0, n_frames / frame_rate, num=n_frames)
        return time, signal



def main(file_path):
    time, signal = read_wav(file_path)

    fft_signal = np.fft.fft(signal)
    frequencies = np.fft.fftfreq(len(signal), d=1.0 / wave.open(file_path, 'r').getframerate())

    positive_freqs = frequencies[:len(frequencies) // 2]
    positive_fft = np.abs(fft_signal[:len(fft_signal) // 2])

    mask = (positive_freqs >= 60) & (positive_freqs <= 600)
    filtered_fft = np.zeros_like(fft_signal)
    filtered_fft[:len(positive_fft)][mask] = fft_signal[:len(positive_fft)][mask]
    filtered_fft[-len(positive_fft):][mask[::-1]] = fft_signal[-len(positive_fft):][mask[::-1]]

    filtered_signal = np.fft.ifft(filtered_fft)

    filtered_signal = np.real(filtered_signal)

    output_file_path = 'saida.wav'
    with wave.open(output_file_path, 'w') as wav_file:
        wav_file.setnchannels(2)
        wav_file.setsampwidth(3) 
        wav_file.setframerate(wave.open(file_path, 'r').getframerate())
        filtered_signal_int16 = np.int16(filtered_signal)
        wav_file.writeframes(filtered_signal_int16.tobytes())

import sys
import os

if __name__ == "__main__":
    os.makedirs('filter', exist_ok=True)
    file_path = 'dump.wav'

    main(file_path)