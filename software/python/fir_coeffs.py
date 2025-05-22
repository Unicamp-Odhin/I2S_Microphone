import numpy as np
import scipy.signal as signal
import matplotlib.pyplot as plt
import argparse
from scipy.special import i0
import math


def fir_lowpass(M, fc_norm, window_type='hamming', beta=0.0):
    n = np.arange(0, M)
    h_ideal = np.sinc(2 * fc_norm * (n - M / 2))

    # Janela de Hamming
    if window_type == 'hamming':
        window = 0.54 - 0.46 * np.cos((2 * np.pi * n) / M)

    # Janela de Hanning
    elif window_type == 'hanning':
        window = 0.5 - 0.5 * np.cos((2 * np.pi * n) / M)

    # Janela de Blackman
    elif window_type == 'blackman':
        window = (
            0.42
            - 0.5 * np.cos((2 * np.pi * n) / M)
            + 0.08 * np.cos((4 * np.pi * n) / M)
        )

    # Janela de Kaiser
    elif window_type == 'kaiser':
        alpha = (M - 1) / 2  # Centro da janela
        a = M / 2  # Largura
        window = i0(beta * np.sqrt(1 - ((n - alpha) / a) ** 2)) / i0(beta)

    # Janela de Bartlett (triangular)
    elif window_type == 'bartlett':
        window = 1 - (2 * np.abs(n - M / 2)) / M

    # Janela Retangular
    elif window_type == 'rectangular':   # media movel com coeficientes iguais
        # Janela retangular é equivalente a não aplicar janela
        window = np.ones(M)

    else:
        raise ValueError(
            'Janela inválida. Use: hamming, hanning, blackman, kaiser, bartlett ou rectangular.'
        )

    h_fir = h_ideal * window
    h_fir /= np.sum(h_fir)  # Normaliza o ganho DC
    return h_fir


def format_verilog(coeffs):
    lines = [
        '    ' + str(c) + (',' if i < len(coeffs) - 1 else '')
        for i, c in enumerate(coeffs)
    ]
    return "'{\n" + '\n'.join(lines) + '\n}'


def main():
    parser = argparse.ArgumentParser(
        description='Gerador de filtro FIR com janela e exportação de coeficientes.'
    )
    parser.add_argument(
        '--order', type=int, default=63, help='Ordem do filtro (default: 63)'
    )
    parser.add_argument(
        '--fc',
        type=float,
        default=4000.0,
        help='Frequência de corte em Hz (default: 4000)',
    )
    parser.add_argument(
        '--fs',
        type=float,
        default=20000.0,
        help='Frequência de amostragem em Hz (default: 20000)',
    )
    parser.add_argument(
        '--window',
        type=str,
        default='hamming',
        choices=[
            'hamming',
            'hanning',
            'blackman',
            'kaiser',
            'bartlett',
            'rectangular',
        ],
        help='Tipo de janela (default: hamming)',
    )
    parser.add_argument(
        '--beta',
        type=float,
        default=5.0,
        help='Parâmetro beta para a janela de Kaiser (default: 5.0)',
    )
    parser.add_argument(
        '--data_size',
        type=int,
        default=16,
        help='Parâmetro beta para a janela de Kaiser (default: 5.0)',
    )
    parser.add_argument(
        '--verilog',
        action='store_true',
        help='Imprime os coeficientes formatados para Verilog',
    )

    args = parser.parse_args()

    M = args.order
    fc = args.fc
    fs = args.fs
    window = args.window
    beta = args.beta
    data_size = args.data_size

    fc_norm = fc / fs

    print(
        f'\n== Filtro FIR: Ordem={M}, fc={fc}Hz, fs={fs}Hz, Janela={window} =='
    )

    h_fir = fir_lowpass(M, fc_norm, window, beta)
    h_fixed = np.round(h_fir * (2**data_size)).astype(int)

    if args.verilog:
        print(
            '\n// Coeficientes FIR formatados para Verilog (signed 16 bits):'
        )
        print(
            'logic signed [{}:0] h [0:{}] = {};'.format(
                data_size - 1, M - 1, format_verilog(h_fixed)
            )
        )
    else:
        print('\nCoeficientes quantizados (16 bits ponto fixo):')
        print(h_fixed.tolist())

    sum_coeff = sum(h_fixed)
    print(f"Soma dos coeficientes: {sum_coeff}")
    log2_sum = math.log2(sum_coeff)
    print(f"Log base 2 da soma dos coeficientes: {log2_sum}")

    # Plota resposta em frequência
    w, h = signal.freqz(h_fir)
    plt.figure(figsize=(10, 4))
    plt.plot(w / np.pi, 20 * np.log10(abs(h)))
    plt.title(f'Resposta em frequência - FIR ({window})')
    plt.xlabel('Frequência Normalizada (×π rad/amostra)')
    plt.ylabel('Magnitude (dB)')
    plt.grid(True)
    plt.tight_layout()
    plt.show()


if __name__ == '__main__':
    main()
