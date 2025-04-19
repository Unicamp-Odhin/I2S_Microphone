import sys
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.widgets import Slider


def read_hex_file(filename):
    data = []
    with open(filename, 'r') as f:
        for line in f:
            hex_value = line.strip()
            if len(hex_value) == 4:  # Espera que cada linha tenha 4 caracteres hexadecimais
                # Converter de hexadecimal para inteiro considerando complemento de dois
                value = int(hex_value, 16)
                if value >= 0x8000:  # Se o número é negativo em complemento de dois
                    value -= 0x10000
                data.append(value)
    return np.array(data)


def plot_data(data):
    fig, ax = plt.subplots()
    plt.subplots_adjust(bottom=0.25)

    # Parâmetros iniciais do gráfico
    window_size = 1000
    t = np.arange(len(data))

    # Plot inicial
    line, = ax.plot(t[:window_size], data[:window_size], lw=1)
    ax.set_xlim(0, window_size)
    ax.set_ylim(np.min(data), np.max(data))
    ax.set_xlabel('Amostra')
    ax.set_ylabel('Valor')
    ax.set_title('Gráfico do arquivo HEX')

    # Slider para scroll
    ax_slider = plt.axes([0.1, 0.1, 0.8, 0.05])
    slider = Slider(ax_slider, 'Scroll', 0, len(data) - window_size, valinit=0, valstep=1)

    def update(val):
        pos = int(slider.val)
        ax.set_xlim(pos, pos + window_size)
        line.set_xdata(t[pos:pos + window_size])
        line.set_ydata(data[pos:pos + window_size])
        ax.figure.canvas.draw_idle()

    slider.on_changed(update)

    plt.show()


if __name__ == "__main__":
    # Lê o arquivo HEX e plota os dados
    # Substitua 'output.hex' pelo caminho do seu arquivo HEX
    input_path = sys.argv[1]
    data = read_hex_file(input_path)
    plot_data(data)
