import os
import re

SEARCH_PATTERNS = {
    'Supabase.instance': re.compile(r'Supabase\.instance'),
    'http.Client(': re.compile(r'http\.Client\('),
    'createOwambeHttpClient': re.compile(r'\bcreateOwambeHttpClient\b'),
    'ServiceRegistry.instance': re.compile(r'ServiceRegistry\.instance'),
    'Mock': re.compile(r'\bMock\w*|class \w*Mock\b'),
    'Fake': re.compile(r'\bFake\w*|class \w*Fake\b'),
    'Dummy': re.compile(r'\bDummy\w*\b', re.IGNORECASE),
    'TODO': re.compile(r'\bTODO\b'),
    'FIXME': re.compile(r'\bFIXME\b'),
    'UnimplementedError': re.compile(r'\bUnimplementedError\b'),
    'UnsupportedError': re.compile(r'\bUnsupportedError\b'),
    'throw Exception': re.compile(r'throw\s+Exception\b'),
    'OrganizerEventStore': re.compile(r'\bOrganizerEventStore\b'),
    'VendorStore': re.compile(r'\bVendorStore\b'),
    'OperationsStore': re.compile(r'\bOperationsStore\b')
}

def scan():
    results = {k: [] for k in SEARCH_PATTERNS.keys()}
    lib_path = os.path.join(os.getcwd(), 'lib')
    
    for root, _, files in os.walk(lib_path):
        for file in files:
            if not file.endswith('.dart'):
                continue
            file_path = os.path.join(root, file)
            rel_path = os.path.relpath(file_path, os.getcwd()).replace('\\', '/')
            
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()
                
            for idx, line in enumerate(lines, 1):
                for key, pattern in SEARCH_PATTERNS.items():
                    if pattern.search(line):
                        results[key].append({
                            'file': rel_path,
                            'line': idx,
                            'code': line.strip()
                        })
                        
    # Print summary
    print("=== CODE EVIDENCE SCAN COMPLETED ===")
    for key, matches in results.items():
        print(f"Pattern '{key}': {len(matches)} matches")
        # Print first few matches for quick verification
        for m in matches[:5]:
            print(f"  {m['file']}:{m['line']} -> {m['code']}")
        print("-" * 40)

if __name__ == '__main__':
    scan()
