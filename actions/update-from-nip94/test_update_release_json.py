import os
import json
import tempfile
import pytest
from unittest.mock import patch
import update_release_json as urj

# Test fixtures
@pytest.fixture
def temp_dir():
    """Create a temporary directory for test files."""
    with tempfile.TemporaryDirectory() as tmpdirname:
        yield tmpdirname


@pytest.fixture
def sample_release_json(temp_dir):
    """Create a sample release.json file for testing."""
    release_data = {
        "version": "0.0.1",
        "modules": [
            {
                "name": "basic",
                "description": "TollGate Basic Module",
                "versions": [
                    {
                        "version": "0.0.1",
                        "architectures": {
                            "aarch64_cortex-a53": {
                                "url": "https://example.com/old.ipk",
                                "hash": "sha256:oldhash",
                                "eventId": "oldeventid"
                            }
                        },
                        "dependencies": []
                    }
                ]
            }
        ]
    }
    
    filepath = os.path.join(temp_dir, "release.json")
    with open(filepath, 'w') as f:
        json.dump(release_data, f, indent=2)
    return filepath


@pytest.fixture
def sample_event(temp_dir):
    """Create a sample NIP-94 event file for testing."""
    event_data = {
        "id": "testeventid123",
        "pubkey": "testpubkey123",
        "created_at": 1743965913,
        "kind": 1063,
        "content": "TollGate Module Package: basic for test",
        "tags": [
            ["url", "https://example.com/new.ipk"],
            ["m", "application/octet-stream"],
            ["x", "newhash123"],
            ["filename", "basic-gl-mt3000-aarch64_cortex-a53.ipk"],
            ["architecture", "aarch64_cortex-a53"]
        ]
    }
    
    filepath = os.path.join(temp_dir, "event.json")
    with open(filepath, 'w') as f:
        json.dump(event_data, f, indent=2)
    return filepath


def test_extract_module_from_filename():
    """Test module name extraction from filenames."""
    # Test case 1: basic-gl-mt3000-aarch64_cortex-a53.ipk
    assert urj.extract_module_from_filename("basic-gl-mt3000-aarch64_cortex-a53.ipk") == "basic"
    
    # Test case 2: tollgate-module-basic-go_1.0.ipk
    assert urj.extract_module_from_filename("tollgate-module-basic-go_1.0.ipk") == "basic"
    
    # Test case 3: tollgate-module-advanced.ipk
    assert urj.extract_module_from_filename("tollgate-module-advanced.ipk") == "advanced"
    
    # Test case 4: Invalid filename
    assert urj.extract_module_from_filename("invalid_filename") is None


def test_load_json_file(sample_release_json):
    """Test loading a JSON file."""
    # Test valid file
    data = urj.load_json_file(sample_release_json)
    assert data is not None
    assert data["version"] == "0.0.1"
    
    # Test invalid file
    with patch('builtins.print'):  # Suppress print output
        data = urj.load_json_file("nonexistent_file.json")
        assert data is None


def test_extract_event_data():
    """Test extracting data from an event."""
    event_data = {
        "id": "testid",
        "created_at": 12345,
        "tags": [
            ["url", "https://example.com/test.ipk"],
            ["x", "testhash"],
            ["architecture", "test_arch"],
            ["filename", "test-filename.ipk"]
        ]
    }
    
    event_id, created_at, url, hash_value, arch, filename = urj.extract_event_data(event_data)
    assert event_id == "testid"
    assert created_at == 12345
    assert url == "https://example.com/test.ipk"
    assert hash_value == "testhash"
    assert architecture == "test_arch"
    assert filename == "test-filename.ipk"


def test_process_events_no_events(temp_dir, sample_release_json):
    """Test processing with no event files."""
    with patch('builtins.print'):  # Suppress print output
        result = urj.process_events(temp_dir, sample_release_json, True)
        assert result is True  # Should succeed but not change anything


def test_process_events_with_event(temp_dir, sample_release_json, sample_event):
    """Test processing with a valid event file."""
    with patch('builtins.print'):  # Suppress print output
        result = urj.process_events(temp_dir, sample_release_json, True)
        assert result is True
    
    # Check that the file was updated
    with open(sample_release_json, 'r') as f:
        updated_data = json.load(f)
    
    arch_data = updated_data["modules"][0]["versions"][0]["architectures"]["aarch64_cortex-a53"]
    assert arch_data["url"] == "https://example.com/new.ipk"
    assert arch_data["hash"] == "sha256:newhash123"
    assert arch_data["eventId"] == "testeventid123"


def test_process_events_multiple_events(temp_dir, sample_release_json):
    """Test processing with multiple events for the same module/architecture."""
    # Create events with different timestamps for same module/architecture
    event1 = {
        "id": "oldevent",
        "created_at": 1000,
        "tags": [
            ["url", "https://example.com/old.ipk"],
            ["x", "oldhash"],
            ["architecture", "aarch64_cortex-a53"],
            ["filename", "basic-old.ipk"]
        ]
    }
    
    event2 = {
        "id": "newevent",
        "created_at": 2000,  # Newer
        "tags": [
            ["url", "https://example.com/new.ipk"],
            ["x", "newhash"],
            ["architecture", "aarch64_cortex-a53"],
            ["filename", "basic-new.ipk"]
        ]
    }
    
    # Write events to files
    with open(os.path.join(temp_dir, "event1.json"), 'w') as f:
        json.dump(event1, f)
    
    with open(os.path.join(temp_dir, "event2.json"), 'w') as f:
        json.dump(event2, f)
    
    # Process events
    with patch('builtins.print'):  # Suppress print output
        result = urj.process_events(temp_dir, sample_release_json, True)
        assert result is True
    
    # Verify only the newer event was used
    with open(sample_release_json, 'r') as f:
        updated_data = json.load(f)
    
    arch_data = updated_data["modules"][0]["versions"][0]["architectures"]["aarch64_cortex-a53"]
    assert arch_data["eventId"] == "newevent"
    assert arch_data["url"] == "https://example.com/new.ipk"
    assert arch_data["hash"] == "sha256:newhash"


def test_process_events_invalid_module(temp_dir, sample_release_json):
    """Test processing with an event for a non-existent module."""
    # Create event with non-existent module
    event = {
        "id": "test_invalid",
        "created_at": 1000,
        "tags": [
            ["url", "https://example.com/test.ipk"],
            ["x", "testhash"],
            ["architecture", "aarch64_cortex-a53"],
            ["filename", "nonexistent-module-test.ipk"]
        ]
    }
    
    # Write event to file
    with open(os.path.join(temp_dir, "invalid_module.json"), 'w') as f:
        json.dump(event, f)
    
    # Process event
    with patch('builtins.print'):  # Suppress print output
        result = urj.process_events(temp_dir, sample_release_json, True)
        assert result is True  # Should succeed but not update anything
    
    # Verify release.json wasn't changed
    with open(sample_release_json, 'r') as f:
        updated_data = json.load(f)
    
    arch_data = updated_data["modules"][0]["versions"][0]["architectures"]["aarch64_cortex-a53"]
    assert arch_data["eventId"] == "oldeventid"  # Still has original value