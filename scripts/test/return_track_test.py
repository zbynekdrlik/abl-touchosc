#!/usr/bin/env python3
"""
Return Track Discovery Script for AbletonOSC
Version: 1.0.0

This script helps discover how AbletonOSC exposes return tracks.
Run this with AbletonOSC's run-console.py or adapt for your OSC client.

Usage:
    python return_track_test.py

Requirements:
    - AbletonOSC installed and running in Ableton Live
    - python-osc package (pip install python-osc)
"""

import time
from pythonosc import udp_client, osc_server, dispatcher
import threading

# Configuration
ABLETONOSC_IP = "127.0.0.1"
ABLETONOSC_PORT = 11000
RECEIVE_PORT = 11001
MAX_TRACKS = 30

# Global storage for responses
responses = {}
response_event = threading.Event()

def response_handler(address, *args):
    """Handle OSC responses from AbletonOSC"""
    responses[address] = args
    print(f"Response: {address} = {args}")
    response_event.set()

def query_osc(client, address, *args, timeout=0.5):
    """Send OSC query and wait for response"""
    global responses
    response_event.clear()
    responses.clear()
    
    print(f"\nQuery: {address} {args}")
    client.send_message(address, args)
    
    if response_event.wait(timeout):
        return responses.get(address)
    else:
        print("  (no response)")
        return None

def test_basic_discovery(client):
    """Test 1: Basic track discovery"""
    print("\n" + "="*50)
    print("TEST 1: Basic Track Discovery")
    print("="*50)
    
    # Get track count
    result = query_osc(client, "/live/song/get/num_tracks")
    track_count = result[0] if result else 0
    print(f"Track count: {track_count}")
    
    # Get track names
    result = query_osc(client, "/live/song/get/track_names")
    if result:
        print(f"Track names: {result}")
        
    # Try return-specific commands
    print("\nTrying return-specific commands...")
    query_osc(client, "/live/song/get/num_return_tracks")
    query_osc(client, "/live/song/get/return_track_names")
    query_osc(client, "/live/song/get/return_tracks")

def test_extended_indices(client):
    """Test 2: Extended index access"""
    print("\n" + "="*50)
    print("TEST 2: Extended Index Access")
    print("="*50)
    
    tracks_found = {}
    
    for i in range(MAX_TRACKS):
        result = query_osc(client, "/live/track/get/name", i)
        if result and len(result) > 1:
            name = result[1]
            track_type = "return" if "Return" in name else "regular"
            tracks_found[i] = {"name": name, "type": track_type}
            print(f"Track {i}: {name} ({track_type})")
    
    return tracks_found

def test_track_properties(client, track_index):
    """Test 3: Track property identification"""
    print("\n" + "="*50)
    print(f"TEST 3: Properties for Track {track_index}")
    print("="*50)
    
    properties = [
        "has_audio_input",
        "has_audio_output",
        "has_midi_input",
        "has_midi_output",
        "can_be_armed",
        "is_foldable",
        "available_input_routing_types"
    ]
    
    track_props = {}
    for prop in properties:
        result = query_osc(client, f"/live/track/get/{prop}", track_index)
        if result:
            track_props[prop] = result[1] if len(result) > 1 else result
            print(f"  {prop}: {track_props[prop]}")
    
    return track_props

def test_return_controls(client, track_index):
    """Test 4: Return track controls"""
    print("\n" + "="*50)
    print(f"TEST 4: Controls for Track {track_index}")
    print("="*50)
    
    # Test volume
    result = query_osc(client, "/live/track/get/volume", track_index)
    if result:
        print(f"Volume: {result}")
        
    # Test mute
    result = query_osc(client, "/live/track/get/mute", track_index)
    if result:
        print(f"Mute: {result}")
        
    # Test meter
    result = query_osc(client, "/live/track/get/output_meter_level", track_index)
    if result:
        print(f"Meter: {result}")

def test_send_levels(client):
    """Test 5: Send levels from regular tracks"""
    print("\n" + "="*50)
    print("TEST 5: Send Levels")
    print("="*50)
    
    # Test first few tracks
    for track in range(4):
        print(f"\nTrack {track} sends:")
        for send in range(4):
            result = query_osc(client, "/live/track/get/send", track, send)
            if result and len(result) > 2:
                print(f"  Send {send}: {result[2]}")

def main():
    """Run all tests"""
    print("AbletonOSC Return Track Discovery")
    print("=================================")
    
    # Set up OSC client
    client = udp_client.SimpleUDPClient(ABLETONOSC_IP, ABLETONOSC_PORT)
    
    # Set up OSC server for responses
    disp = dispatcher.Dispatcher()
    disp.set_default_handler(response_handler)
    
    server = osc_server.ThreadingOSCUDPServer(
        ("127.0.0.1", RECEIVE_PORT), disp
    )
    server_thread = threading.Thread(target=server.serve_forever)
    server_thread.daemon = True
    server_thread.start()
    
    print(f"Listening for responses on port {RECEIVE_PORT}")
    time.sleep(0.5)
    
    try:
        # Run tests
        test_basic_discovery(client)
        tracks = test_extended_indices(client)
        
        # Test properties on potential return tracks
        return_tracks = [i for i, t in tracks.items() if t["type"] == "return"]
        if return_tracks:
            print(f"\nFound potential return tracks at indices: {return_tracks}")
            for idx in return_tracks[:2]:  # Test first 2 returns
                test_track_properties(client, idx)
                test_return_controls(client, idx)
        else:
            print("\nNo return tracks found with extended indexing")
            
        test_send_levels(client)
        
        # Summary
        print("\n" + "="*50)
        print("SUMMARY")
        print("="*50)
        print(f"Total tracks found: {len(tracks)}")
        print(f"Return tracks found: {len(return_tracks)}")
        if return_tracks:
            print("Return track access method: Extended indexing")
            print(f"Return track indices: {return_tracks}")
        else:
            print("Return track access method: Unknown (needs more testing)")
            
    except KeyboardInterrupt:
        print("\nTest interrupted")
    finally:
        server.shutdown()

if __name__ == "__main__":
    main()
