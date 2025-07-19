#!/usr/bin/env python3
"""
Quick fix script for common Flutter analyzer issues
"""
import os
import re
import glob

def fix_with_opacity_issues(directory):
    """Fix withOpacity deprecation warnings"""
    dart_files = glob.glob(os.path.join(directory, "**/*.dart"), recursive=True)
    
    for file_path in dart_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Replace withOpacity with withValues
            updated_content = re.sub(
                r'\.withOpacity\(([^)]+)\)',
                r'.withValues(alpha: \1)',
                content
            )
            
            if updated_content != content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(updated_content)
                print(f"Fixed withOpacity issues in: {file_path}")
                
        except Exception as e:
            print(f"Error processing {file_path}: {e}")

def fix_private_type_issues(directory):
    """Fix private type in public API issues"""
    dart_files = glob.glob(os.path.join(directory, "**/*.dart"), recursive=True)
    
    for file_path in dart_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Replace _StateClass createState() with State<Widget> createState()
            updated_content = re.sub(
                r'(\s+)_([A-Za-z0-9_]+)State createState\(\) => _([A-Za-z0-9_]+)State\(\);',
                r'\1State<\2> createState() => _\3State();',
                content
            )
            
            if updated_content != content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(updated_content)
                print(f"Fixed private type issues in: {file_path}")
                
        except Exception as e:
            print(f"Error processing {file_path}: {e}")

def fix_interpolation_issues(directory):
    """Fix string interpolation issues"""
    dart_files = glob.glob(os.path.join(directory, "**/*.dart"), recursive=True)
    
    for file_path in dart_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Replace simple string concatenation with interpolation
            # This is a basic pattern - may need manual review for complex cases
            updated_content = re.sub(
                r'(["\'])([^"\']*)\1\s*\+\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\+\s*(["\'])([^"\']*)\4',
                r'"\2$\3\5"',
                content
            )
            
            if updated_content != content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(updated_content)
                print(f"Fixed interpolation issues in: {file_path}")
                
        except Exception as e:
            print(f"Error processing {file_path}: {e}")

if __name__ == "__main__":
    lib_directory = r"d:\NMMT_FLUTTER\NaviBus\NaviBus\lib"
    
    print("Fixing Flutter analyzer issues...")
    print("1. Fixing withOpacity deprecation warnings...")
    fix_with_opacity_issues(lib_directory)
    
    print("\n2. Fixing private type in public API issues...")
    fix_private_type_issues(lib_directory)
    
    print("\n3. Fixing string interpolation issues...")
    fix_interpolation_issues(lib_directory)
    
    print("\nDone! Please run 'flutter analyze' again to see the improvements.")
