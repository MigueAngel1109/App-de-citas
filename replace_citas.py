import os
import re

def replace_in_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Define the replacements
    # We use regex with word boundaries \b to avoid replacing substrings inside other words, 
    # though "cita" is rarely part of another word in Spanish except maybe "solicitar". 
    # Wait, "solicitar" -> "solicitar" (not "solireservar"). So \b is important.
    
    replacements = [
        (r'\bCitas\b', 'Reservas'),
        (r'\bcitas\b', 'reservas'),
        (r'\bCITAS\b', 'RESERVAS'),
        (r'\bCita\b', 'Reserva'),
        (r'\bcita\b', 'reserva'),
        (r'\bCITA\b', 'RESERVA'),
    ]
    
    new_content = content
    for pattern, replacement in replacements:
        new_content = re.sub(pattern, replacement, new_content)
        
    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

def main():
    lib_dir = r"c:\Flutter_Proyectos\app_pruebas\lib"
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith(".dart"):
                replace_in_file(os.path.join(root, file))

if __name__ == "__main__":
    main()
