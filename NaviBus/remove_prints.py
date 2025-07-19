#!/usr/bin/env python3
"""
Remove print statements for production build
"""
import os
import re
import glob

def remove_print_statements(directory):
    """Remove or replace print statements with proper logging"""
    dart_files = glob.glob(os.path.join(directory, "**/*.dart"), recursive=True)
    
    for file_path in dart_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Replace print statements with debugPrint or comments
            updated_content = re.sub(
                r'(\s*)print\(([^)]+)\);',
                r'\1// debugPrint(\2); // Removed for production',
                content
            )
            
            if updated_content != content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(updated_content)
                print(f"Removed print statements from: {file_path}")
                
        except Exception as e:
            print(f"Error processing {file_path}: {e}")

if __name__ == "__main__":
    lib_directory = r"d:\NMMT_FLUTTER\NaviBus\NaviBus\lib"
    
    print("Removing print statements for production...")
    remove_print_statements(lib_directory)
    print("Done!")
