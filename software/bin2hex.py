import sys
import os

def bin_to_hex_file(input_path, output_path, n):
    try:
        with open(input_path, 'r') as infile:
            binary_string = infile.read().strip()
        
        hex_numbers = [format(int(binary_string[i:i+16], 2), '04X') for i in range(n, len(binary_string) - 16 + n, 16)]
        
        with open(output_path, 'w') as outfile:
            outfile.write('\n'.join(hex_numbers))
        
        print(f"Arquivo convertido com sucesso: {output_path}")
    except Exception as e:
        print(f"Erro: {e}")

# if __name__ == "__main__":
#     input_path = sys.argv[1]
#     output_path = sys.argv[2]
#     n = 0
#     if '-n' in sys.argv:
#         try:
#             n = int(sys.argv[sys.argv.index('-n') + 1])
#         except (ValueError, IndexError):
#             print("Erro: O argumento após '-n' deve ser um número válido.")
#             sys.exit(1)

#     bin_to_hex_file(input_path, output_path, n)

if __name__ == "__main__":
    input_path = sys.argv[1]
    output_path = sys.argv[2]
    os.makedirs("hex", exist_ok=True)
    for n in range(0, 16):
        bin_to_hex_file(input_path, "hex/" + output_path.replace(".hex", f"_{n}.hex"), n)