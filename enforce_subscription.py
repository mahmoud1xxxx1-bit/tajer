import os
import re

file_path = 'lib/features/authentication/data/auth_repository.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Bypass plan for love.dotk@gmail.com in appUser stream
app_user_stream_regex = r"(if \(snapshot\.exists && snapshot\.data\(\) != null\) {\s*final data = snapshot\.data\(\)!;)"
app_user_stream_replacement = r"\1\n        if (data['email'] == 'love.dotk@gmail.com') {\n          data['plan'] = 'premium';\n        }"
content = re.sub(app_user_stream_regex, app_user_stream_replacement, content)

# 2. Enforce premium when creating employee
create_emp_regex = r"(Future<void> createEmployee.*?{)"
create_emp_replacement = r"\1\n      // Check subscription\n      final merchantDoc = await _firestore.collection('users').doc(_auth.currentUser?.uid).get();\n      final plan = merchantDoc.data()?['plan'] ?? 'merchant';\n      if (plan != 'premium' && merchantDoc.data()?['email'] != 'love.dotk@gmail.com') {\n        throw Exception('UO U.UUU+O OO"OU.O O U,OU,OU% OU,O O OO-UOOU U,U? OU,O OU,O U,OU?O-O_USO .');\n      }"
content = re.sub(create_emp_regex, create_emp_replacement, content)

# 3. Enforce premium when employee logs in
# First, let's find the login method
# Wait, signInWithEmailAndPassword might be in auth_repository.dart
