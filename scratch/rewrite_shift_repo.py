import re

path = 'lib/features/shifts/data/shift_repository.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

if 'import \'package:cloud_functions/cloud_functions.dart\';' not in content:
    content = content.replace('import \'package:flutter/foundation.dart\';', 'import \'package:flutter/foundation.dart\';\nimport \'package:cloud_functions/cloud_functions.dart\';\nimport \'package:uuid/uuid.dart\';')

def replace_method(content, method_name, new_impl):
    match = re.search(r"Future<.*?>\s+" + method_name + r"[\s\S]*?async\s*\{", content)
    if not match:
        return content
    
    start_idx = match.end()
    brace_count = 1
    end_idx = start_idx
    while brace_count > 0 and end_idx < len(content):
        if content[end_idx] == '{':
            brace_count += 1
        elif content[end_idx] == '}':
            brace_count -= 1
        end_idx += 1
        
    return content[:start_idx] + "\n" + new_impl + "\n" + content[end_idx-1:]


new_close_shift = """
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('closeShift');
      final operationId = const Uuid().v4();
      
      await callable.call({
        'operationId': operationId,
        'shiftId': shift.id,
        'actualCash': shift.actualCash,
        'actualCard': shift.actualCard,
        'actualTransfer': shift.actualTransfer,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Server Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to close shift: $e');
    }
"""

content = replace_method(content, 'closeShift', new_close_shift)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Rewritten shift repository successfully!")
