#!/usr/bin/env python3

import json
import sys
import os
import re
import glob
import argparse
from typing import Dict, List, Optional, Any, Tuple


def parse_arguments():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Update release.json with NIP-94 events')
    parser.add_argument('--events-dir', required=True, help='Directory containing NIP-94 event files')
    parser.add_argument('--release-json', required=True, help='Path to release.json file')
    parser.add_argument('--verbose', action='store_true', help='Enable verbose output')
    return parser.parse_args()


def load_json_file(file_path: str) -> Optional[Dict]:
    """Load JSON from file.
    
    Args:
        file_path: Path to the JSON file
        
    Returns:
        Parsed JSON data as dictionary or None if file could not be parsed
    """
    try:
        with open(file_path, 'r') as f:
            return json.load(f)
    except (json.JSONDecodeError, FileNotFoundError) as e:
        print(f"Error loading {file_path}: {e}")
        return None


def extract_module_from_filename(filename: str) -> Optional[str]:
    """Extract module name from filename.
    
    Args:
        filename: The filename to extract module name from
        
    Returns:
        Module name or None if it couldn't be extracted
    """
    # Pattern 1: tollgate-module-basic-go*  (MORE SPECIFIC - CHECK FIRST)
    match = re.match(r'tollgate-module-(.+)-go', filename)
    if match:
        return match.group(1)
        
    # Pattern 2: tollgate-module-basic.ipk
    match = re.match(r'tollgate-module-([^.]+)(?:\.|$)', filename)
    if match:
        return match.group(1)
    
    # Pattern 3: basic-gl-mt3000-*.ipk  (MOST GENERIC - CHECK LAST)
    match = re.match(r'^([^-]+)-', filename)
    if match:
        return match.group(1)
    
    return None


def extract_event_data(event_data: Dict) -> Tuple[str, int, Optional[str], Optional[str], Optional[str], Optional[str]]:
    """Extract relevant data from NIP-94 event.
    
    Args:
        event_data: The parsed event data
        
    Returns:
        Tuple of (event_id, created_at, url, hash_value, architecture, filename)
    """
    event_id = event_data.get('id', '')
    created_at = event_data.get('created_at', 0)
    
    # Extract tags
    url = None
    hash_value = None
    architecture = None
    filename = None
    
    for tag in event_data.get('tags', []):
        if len(tag) < 2:
            continue
            
        if tag[0] == 'url':
            url = tag[1]
        elif tag[0] == 'x':
            hash_value = tag[1]
        elif tag[0] == 'architecture':
            architecture = tag[1]
        elif tag[0] == 'filename':
            filename = tag[1]
    
    return event_id, created_at, url, hash_value, architecture, filename


def process_events(events_dir: str, release_json_path: str, verbose: bool = False) -> bool:
    """Process NIP-94 events and update release.json.
    
    Args:
        events_dir: Directory containing event files
        release_json_path: Path to the release.json file
        verbose: Whether to print verbose output
        
    Returns:
        True if processing was successful, False otherwise
    """
    # Load the release.json file
    release_data = load_json_file(release_json_path)
    if not release_data:
        print(f"Error: Could not load {release_json_path}")
        return False
    
    # Extract available modules from release.json
    available_modules = [module['name'] for module in release_data.get('modules', [])]
    if verbose:
        print(f"Available modules in release.json: {available_modules}")
    
    # Get all event files
    event_files = glob.glob(os.path.join(events_dir, '*.json'))
    if not event_files:
        print(f"No event files found in {events_dir}")
        return True  # Not an error, just nothing to do
    
    if verbose:
        print(f"Found {len(event_files)} event files")
    
    # Organize events by module and architecture
    events_by_key = {}
    for event_file in event_files:
        event_data = load_json_file(event_file)
        if not event_data:
            print(f"Warning: Could not parse {event_file}, skipping")
            continue
        
        # Extract event details
        event_id, created_at, url, hash_value, architecture, filename = extract_event_data(event_data)
        
        # Skip events with missing required fields
        if not all([url, hash_value, architecture, filename]):
            print(f"Warning: Event {event_id} missing required fields, skipping")
            continue
        
        # Extract module name from filename
        module = extract_module_from_filename(filename)
        if not module:
            print(f"Warning: Could not extract module name from {filename}, skipping")
            continue
        
        # Skip if module not in release.json
        if module not in available_modules:
            print(f"Warning: Module {module} not found in release.json, skipping")
            continue
        
        # Create a key for this module/architecture
        key = f"{module}-{architecture}"
        
        # Add to events_by_key, keeping track of timestamp for sorting
        if key not in events_by_key or events_by_key[key]['created_at'] < created_at:
            events_by_key[key] = {
                'module': module,
                'architecture': architecture,
                'url': url,
                'hash': hash_value,
                'event_id': event_id,
                'created_at': created_at
            }
    
    # No valid events found
    if not events_by_key:
        print("No valid events found to process")
        return True
    
    # Process the events and update release.json
    update_count = 0
    for key, event in events_by_key.items():
        module = event['module']
        architecture = event['architecture']
        url = event['url']
        hash_value = event['hash']
        event_id = event['event_id']
        
        # Find the module in release.json
        for release_module in release_data['modules']:
            if release_module['name'] == module:
                # Update all versions for this module/architecture
                for version in release_module['versions']:
                    if 'architectures' not in version:
                        version['architectures'] = {}
                    
                    # Update the architecture entry
                    version['architectures'][architecture] = {
                        'url': url,
                        'hash': f"sha256:{hash_value}",
                        'eventId': event_id
                    }
                    update_count += 1
                    
                    if verbose:
                        print(f"Updated {module}/{architecture} with event {event_id}")
    
    # Save the updated release.json
    if update_count > 0:
        with open(release_json_path, 'w') as f:
            json.dump(release_data, f, indent=2)
        print(f"Successfully updated release.json with {update_count} changes")
        return True
    else:
        print("No updates were made to release.json")
        return True


def main():
    """Main entry point."""
    args = parse_arguments()
    
    success = process_events(
        args.events_dir,
        args.release_json,
        args.verbose
    )
    
    if not success:
        sys.exit(1)


if __name__ == "__main__":
    main()
