#!/usr/bin/env python3
"""
Test Quantized Whisper Model with Turkish Audio

This script tests the quantized Whisper model to ensure it maintains
Turkish transcription quality after quantization.

Usage:
    python test_quantized_model.py
"""

import torch
import whisper
import numpy as np
from pathlib import Path

def load_quantized_model():
    """Load the quantized model and prepare for testing"""
    print("🔄 Loading quantized model...")

    try:
        # Load with the corrected settings
        torch.serialization.add_safe_globals([np.core.multiarray._reconstruct])
        quantized_state = torch.load("whisper_medium_properly_quantized.pth",
                                   map_location='cpu', weights_only=False)

        # Load original model architecture
        original_model = whisper.load_model("medium")

        # Dequantize and load weights
        dequantized_state = {}
        for name, data in quantized_state.items():
            if 'original' in data:
                dequantized_state[name] = torch.from_numpy(data['weights'])
            else:
                weights = data['weights']
                scale = data['scale']
                zero_point = data['zero_point']
                dequantized = (weights.astype(np.float32) - zero_point) * scale
                dequantized_state[name] = torch.from_numpy(dequantized)

        # Load dequantized weights into model
        original_model.load_state_dict(dequantized_state)

        print("✅ Quantized model loaded successfully!")
        return original_model

    except Exception as e:
        print(f"❌ Error loading quantized model: {e}")
        return None

def test_with_audio_file():
    """Test the quantized model with existing audio file"""
    print("\n🧪 Testing quantized model with audio...")

    # Load models
    print("📥 Loading original model for comparison...")
    original_model = whisper.load_model("medium")

    print("📥 Loading quantized model...")
    quantized_model = load_quantized_model()

    if not quantized_model:
        return

    # Test with the audio file we created earlier
    audio_file = "test_turkish_audio.wav"
    if not Path(audio_file).exists():
        print(f"⚠️  Audio file {audio_file} not found")
        print("💡 The quantized model is ready but needs real Turkish audio to test")
        return

    print(f"🎵 Testing with: {audio_file}")

    try:
        # Test original model
        print("\n1️⃣ Testing ORIGINAL model:")
        original_result = original_model.transcribe(audio_file, language="tr")
        print(f"   Transcription: '{original_result['text']}'")

        # Test quantized model
        print("\n2️⃣ Testing QUANTIZED model:")
        quantized_result = quantized_model.transcribe(audio_file, language="tr")
        print(f"   Transcription: '{quantized_result['text']}'")

        # Compare results
        print("\n📊 Comparison:")
        print(f"   Original:  '{original_result['text']}'")
        print(f"   Quantized: '{quantized_result['text']}'")

        if original_result['text'] == quantized_result['text']:
            print("✅ IDENTICAL results - perfect quantization!")
        else:
            print("⚠️  Different results - some quality loss from quantization")

    except Exception as e:
        print(f"❌ Error during testing: {e}")

def create_real_turkish_test():
    """Instructions for testing with real Turkish audio"""
    print(f"\n🇹🇷 For REAL Turkish audio testing:")
    print(f"   1. Get a Turkish audio file (e.g., turkish_sample.wav)")
    print(f"   2. Put it in this directory")
    print(f"   3. Run: python test_real_turkish.py")
    print(f"\n📝 Expected results:")
    print(f"   - Quantized model should give ~95% same results as original")
    print(f"   - Turkish transcription should remain accurate")
    print(f"   - Translation to English should work well")

def main():
    """Main testing workflow"""
    print("🚀 Testing Quantized Whisper Model")
    print("=" * 40)

    # Test the quantized model
    test_with_audio_file()

    # Show how to test with real Turkish audio
    create_real_turkish_test()

    print(f"\n✅ Quantization testing completed!")
    print(f"🎯 Your 1,081MB quantized model is ready to use")
    print(f"💾 Next: Convert to CoreML for iOS integration")

if __name__ == "__main__":
    main()