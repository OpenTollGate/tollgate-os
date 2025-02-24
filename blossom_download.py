#!/usr/bin/env python3

import sys
import json
import subprocess
import hashlib
import os
import tempfile
import re
import ssl
import time
from nostr.filter import Filter, Filters
from nostr.event import Event, EventKind
from nostr.relay_manager import RelayManager
from nostr.message_type import ClientMessageType

# Add debug logging
DEBUG = True

def debug_print(msg):
    if DEBUG:
        print(f"DEBUG: {msg}")

def calculate_sha256(file_path):
    """Calculate SHA256 hash of a file"""
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

def download_file(server, file_hash, output_dir, filename, secret_key):
    """Download file from server and save to output directory"""
    env = os.environ.copy()
    env['NOSTR_SECRET_KEY'] = secret_key
    
    output_path = os.path.join(output_dir, filename)
    
    with open(output_path, 'wb') as f:
        download_proc = subprocess.run(
            ['blossom', 'download', '-server', server, file_hash],
            stdout=f,
            env=env
        )
        
    if download_proc.returncode != 0:
        return False
        
    # Verify hash
    downloaded_hash = calculate_sha256(output_path)
    return downloaded_hash == file_hash

def extract_json_from_note(note_text):
    """Extract JSON content from a note"""
    debug_print(f"Processing note text:\n{note_text}")
    
    # Look for content between triple backticks
    json_match = re.search(r'```\s*\n(.*?)\n\s*```', note_text, re.DOTALL)
    if not json_match:
        debug_print("No JSON content found between backticks")
        return None
        
    json_content = json_match.group(1)
    debug_print(f"Extracted JSON content:\n{json_content}")
    
    try:
        return json.loads(json_content)
    except json.JSONDecodeError as e:
        debug_print(f"JSON parsing error: {e}")
        return None

def get_architecture_event(pubkey, relays, target_arch):
    """Get the event matching the specified architecture"""
    try:
        filters = Filters([Filter(authors=[pubkey], kinds=[EventKind.TEXT_NOTE], limit=10)])
        subscription_id = "binary_fetch"
        request = [ClientMessageType.REQUEST, subscription_id]
        request.extend(filters.to_json_array())

        relay_manager = RelayManager()
        for relay in relays:
            relay_manager.add_relay(relay)
            
        relay_manager.add_subscription(subscription_id, filters)
        relay_manager.open_connections({"cert_reqs": ssl.CERT_NONE})
        time.sleep(1.25)  # allow connections to open

        message = json.dumps(request)
        relay_manager.publish_message(message)
        time.sleep(1)  # allow messages to send

        while relay_manager.message_pool.has_events():
            event_msg = relay_manager.message_pool.get_event()
            debug_print(f"Received event content:\n{event_msg.event.content}")
            
            # Check if event contains the target architecture
            if target_arch in event_msg.event.content:
                json_data = extract_json_from_note(event_msg.event.content)
                if json_data and 'binaries' in json_data:
                    # Verify architecture in target_info
                    if json_data.get('target_info', {}).get('full_arch') == target_arch:
                        relay_manager.close_connections()
                        return json_data

        relay_manager.close_connections()
        debug_print(f"No valid binary data found for architecture: {target_arch}")
        return None

    except Exception as e:
        debug_print(f"Error getting event: {e}")
        return None

# Replace the secrets file reading section with:
def get_secrets_from_env():
    """Get secrets from environment variables"""
    required_vars = {
        'NOSTR_SECRET_KEY': 'secret_key',
        'NOSTR_PUBLIC_KEY': 'public_key_hex',
        'NOSTR_RELAYS': 'relays'
    }
    
    secrets = {}
    for env_var, secret_key in required_vars.items():
        value = os.environ.get(env_var)
        if not value:
            raise ValueError(f"Required environment variable {env_var} not set")
        if secret_key == 'relays':
            secrets[secret_key] = value.split(',')
        else:
            secrets[secret_key] = value
    return secrets

def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <output_directory> <architecture>")
        print("Example architectures: aarch64_cortex-a53, mips_24kc")
        sys.exit(1)

    output_dir = sys.argv[1]
    target_arch = sys.argv[2]

    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)

    try:
        secrets = get_secrets_from_env()
        secret_key = secrets['secret_key']
        relays = secrets['relays']
        pubkey = secrets['public_key_hex']
    except ValueError as e:
        print(f"Error reading secrets from environment: {str(e)}")
        sys.exit(1)

    # Get event for specified architecture
    data = get_architecture_event(pubkey, relays, target_arch)
    if not data:
        print(f"No valid events found for architecture: {target_arch}")
        sys.exit(1)

    print(f"Found event for {target_arch} (platform: {data['target_info']['target_platform']})")

    # Download binaries
    for filename, info in data['binaries'].items():
        file_hash = info['file_hash']
        servers = info['servers']
        
        if not servers:
            print(f"Skipping {filename}: No servers available")
            continue

        print(f"Downloading {filename}...")
        success = False
        
        for server in servers:
            print(f"Trying server: {server}")
            if download_file(server, file_hash, output_dir, filename, secret_key):
                print(f"Successfully downloaded {filename}")
                success = True
                break
        
        if not success:
            print(f"Failed to download {filename} from any server")

if __name__ == "__main__":
    main()
