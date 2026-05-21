import sys
import re
from pathlib import Path

def get_block_id(line):
    """Extrae el ID de un comentario de control tipo <!-- gentle-ai:ID -->"""
    match = re.search(r'<!--\s*gentle-ai:([\w-]+)\s*-->', line)
    return match.group(1) if match else None

def parse_md_to_blocks(content):
    """
    Divide el markdown en bloques basados en comentarios de control.
    Si no hay comentarios, usa Headers como fallback.
    """
    blocks = {}
    current_id = "header_meta" # Bloque inicial antes de cualquier tag
    current_content = []
    
    lines = content.splitlines()
    for line in lines:
        new_id = get_block_id(line)
        if new_id:
            # Guardamos el bloque anterior
            if current_content:
                blocks[current_id] = blocks.get(current_id, []) + current_content
            current_id = new_id
            current_content = [line] # Incluimos el tag
        else:
            current_content.append(line)
            
    if current_content:
        blocks[current_id] = blocks.get(current_id, []) + current_content
        
    return blocks

def deduplicate_lines(lines):
    """Elimina líneas duplicadas manteniendo el orden, pero ignora líneas vacías"""
    seen = set()
    result = []
    for line in lines:
        stripped = line.strip()
        if not stripped:
            result.append(line)
            continue
        if stripped not in seen:
            result.append(line)
            seen.add(stripped)
    return result

def merge_gentle_md(files):
    all_blocks = {}
    # Orden de aparicion original para intentar mantenerlo
    order = []

    for file_path in files:
        path = Path(file_path)
        if not path.exists(): continue
        
        blocks = parse_md_to_blocks(path.read_text())
        for bid, content in blocks.items():
            if bid not in all_blocks:
                order.append(bid)
                all_blocks[bid] = content
            else:
                # Si ya existe, combinamos y deduplicamos
                # El tag de cierre se maneja solo porque parse_md_to_blocks lo incluye si existe
                all_blocks[bid].extend(content)

    final_output = []
    for bid in order:
        content = deduplicate_lines(all_blocks[bid])
        final_output.extend(content)
        # Asegurar espacio entre bloques si no lo hay
        if final_output and final_output[-1].strip():
            final_output.append("")

    return "\n".join(final_output)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: merge_gentle.py <file1> <file2> ...")
        sys.exit(1)
    
    print(merge_gentle_md(sys.argv[1:]))
