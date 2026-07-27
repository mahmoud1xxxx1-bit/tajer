import os
import re
import json

arb_ar = {}

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Regex to match strings in single or double quotes
    pattern = re.compile(r"(['\"])(.*?[\u0600-\u06FF]+.*?)\1")
    
    for match in pattern.finditer(content):
        inner_text = match.group(2)
        if '$' in inner_text:
            continue
            
        # simple key generation
        # use an incrementing index
        if inner_text not in arb_ar.values():
            key = f"text_{len(arb_ar) + 1}"
            arb_ar[key] = inner_text

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))

with open('extracted.json', 'w', encoding='utf-8') as f:
    json.dump(arb_ar, f, ensure_ascii=False, indent=2)

print(f"Extracted {len(arb_ar)} strings.")
