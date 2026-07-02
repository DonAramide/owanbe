import os
import re

UI_PATHS = [
    'lib/features',
    'lib/portals'
]

FORBIDDEN_PATTERNS = {
    'Supabase.instance': re.compile(r'Supabase\.instance'),
    'SupabaseClient': re.compile(r'\bSupabaseClient\b'),
    'PostgrestClient': re.compile(r'\bPostgrestClient\b'),
    'StorageClient': re.compile(r'\bStorageClient\b'),
    'Dio': re.compile(r'\bDio\b'),
    'http.Client': re.compile(r'http\.Client\('),
    'DriftDatabase': re.compile(r'\bDriftDatabase\b'),
    'SharedPreferences': re.compile(r'\bSharedPreferences\b'),
}

FORBIDDEN_IMPORTS = [
    'package:drift',
    'package:sqlite',
    'package:http/http.dart',
    'package:dio'
]

def scan():
    violations = []
    for path in UI_PATHS:
        full_path = os.path.join(os.getcwd(), path)
        if not os.path.exists(full_path):
            continue
        for root, _, files in os.walk(full_path):
            for file in files:
                if not file.endswith('.dart'):
                    continue
                file_path = os.path.join(root, file)
                
                # Exclude mocks, stores, or test files if they are meant to have exceptions
                # However, our goal is zero violations in Widgets/Screens/Controllers/Providers
                # Let's see what violations remain.
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    lines = f.readlines()
                    
                for idx, line in enumerate(lines, 1):
                    # Check for forbidden imports
                    if 'import' in line:
                        for imp in FORBIDDEN_IMPORTS:
                            if imp in line:
                                violations.append({
                                    'file': file_path,
                                    'line': idx,
                                    'type': 'Forbidden Import',
                                    'content': line.strip(),
                                    'detail': f'Import of {imp}'
                                })
                    # Check for forbidden patterns
                    for name, pattern in FORBIDDEN_PATTERNS.items():
                        if pattern.search(line):
                            violations.append({
                                'file': file_path,
                                'line': idx,
                                'type': 'Forbidden Reference',
                                'content': line.strip(),
                                            'detail': f'Reference to {name}'
                                        })
    
    print(f"--- ARCHITECTURE VERIFICATION REPORT ---")
    print(f"Scanned directory paths: {UI_PATHS}")
    print(f"Total Violations: {len(violations)}")
    print("-----------------------------------------")
    for v in violations:
        print(f"Violation: {v['type']}")
        print(f"File: {v['file']}:{v['line']}")
        print(f"Detail: {v['detail']}")
        print(f"Code: {v['content']}")
        print("-----------------------------------------")

if __name__ == '__main__':
    scan()
