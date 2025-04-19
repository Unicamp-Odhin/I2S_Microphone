import sys

def hex_to_bin_file(input_path, output_path):
    try:
        with open(input_path, 'r') as infile:
            hex_numbers = infile.read().splitlines()
        
        binary_string = ''.join(format(int(hex_num, 16), '016b') for hex_num in hex_numbers)
        
        with open(output_path, 'w') as outfile:
            outfile.write(binary_string)
        
        print(f"Arquivo convertido com sucesso: {output_path}")
    except Exception as e:
        print(f"Erro: {e}")

if __name__ == "__main__":
    input_path = sys.argv[1]
    output_path = input_path.replace(".hex", ".bin")
    hex_to_bin_file(input_path, output_path)