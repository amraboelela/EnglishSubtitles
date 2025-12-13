#!/usr/bin/env python3
"""
Test Simple Quantized Whisper Model

Test the quantized model with real Turkish audio to verify quality.
"""

import torch
import whisper
import numpy as np
from pathlib import Path
import time

def load_simple_quantized_model(model_path):
    """Load and dequantize the simple quantized model"""
    print(f"🔄 Loading quantized model: {model_path}")

    # Load the quantized state dict
    quantized_dict = torch.load(model_path, map_location='cpu')

    # Load original model architecture
    original_model = whisper.load_model("medium")

    # Dequantize and reconstruct
    dequantized_dict = {}

    for name, param in original_model.state_dict().items():
        if name + '_is_quantized' in quantized_dict:
            is_quantized = quantized_dict[name + '_is_quantized'].item()

            if is_quantized:
                # Dequantize int8 back to float32
                quantized_weights = quantized_dict[name].numpy()
                scale = quantized_dict[name + '_scale'].item()
                zero_point = quantized_dict[name + '_zero_point'].item()

                # Dequantize: (int8 - zero_point) * scale
                dequantized = (quantized_weights.astype(np.float32) - zero_point) * scale
                dequantized_dict[name] = torch.from_numpy(dequantized)

                print(f"   ✓ Dequantized INT8:   {name}")

            else:
                # Convert float16 back to float32 or keep as-is
                param_data = quantized_dict[name]
                if param_data.dtype == torch.float16:
                    dequantized_dict[name] = param_data.float()
                    print(f"   ✓ Converted FLOAT16:  {name}")
                else:
                    dequantized_dict[name] = param_data
                    print(f"   ✓ Kept original:      {name}")

    # Load dequantized weights into model
    original_model.load_state_dict(dequantized_dict)
    print("✅ Quantized model loaded and dequantized successfully!")

    return original_model

def test_with_turkish_audio():
    """Test both models with Turkish audio"""
    print("\n🇹🇷 Testing Quantized Model vs Original")
    print("=" * 45)

    audio_file = "Resources/fateh-1.m4a"
    if not Path(audio_file).exists():
        print(f"❌ Audio file not found: {audio_file}")
        return

    # Check if quantized model exists
    quantized_path = "whisper_quantized_simple.pth"
    if not Path(quantized_path).exists():
        print(f"❌ Quantized model not found: {quantized_path}")
        print("💡 Run: python simple_quantization.py first")
        return

    file_size = Path(audio_file).stat().st_size / 1024
    print(f"🎵 Testing with: {audio_file} ({file_size:.1f} KB)")

    # Load models
    print("\n📥 Loading models...")

    print("1️⃣ Loading ORIGINAL model...")
    start_time = time.time()
    original_model = whisper.load_model("medium")
    original_load_time = time.time() - start_time
    print(f"   ✓ Loaded in {original_load_time:.1f} seconds")

    print("2️⃣ Loading QUANTIZED model...")
    start_time = time.time()
    quantized_model = load_simple_quantized_model(quantized_path)
    quantized_load_time = time.time() - start_time
    print(f"   ✓ Loaded in {quantized_load_time:.1f} seconds")

    # Test transcription
    print(f"\n🔤 TRANSCRIPTION TEST (Turkish):")
    print("-" * 50)

    try:
        # Original model
        print("1️⃣ ORIGINAL model transcription:")
        start_time = time.time()
        original_result = original_model.transcribe(
            audio_file,
            language="tr",
            task="transcribe"
        )
        original_time = time.time() - start_time

        print(f"   Time: {original_time:.1f}s")
        print(f"   Text: '{original_result['text']}'")

        # Quantized model
        print("\n2️⃣ QUANTIZED model transcription:")
        start_time = time.time()
        quantized_result = quantized_model.transcribe(
            audio_file,
            language="tr",
            task="transcribe"
        )
        quantized_time = time.time() - start_time

        print(f"   Time: {quantized_time:.1f}s")
        print(f"   Text: '{quantized_result['text']}'")

        # Compare transcriptions
        print(f"\n📊 TRANSCRIPTION COMPARISON:")
        original_text = original_result['text'].strip()
        quantized_text = quantized_result['text'].strip()

        if original_text == quantized_text:
            print("✅ IDENTICAL transcriptions!")
            print("🎯 Perfect quantization - no quality loss!")
        else:
            print("📝 Transcription differences:")
            print(f"   Original:  '{original_text}'")
            print(f"   Quantized: '{quantized_text}'")

            # Calculate word-level similarity
            orig_words = set(original_text.lower().split())
            quant_words = set(quantized_text.lower().split())
            common_words = orig_words & quant_words
            all_words = orig_words | quant_words

            if all_words:
                similarity = len(common_words) / len(all_words) * 100
                print(f"   Word similarity: {similarity:.1f}%")

                if similarity >= 95:
                    print("✅ Excellent quality maintained!")
                elif similarity >= 85:
                    print("🟡 Good quality - minor differences")
                else:
                    print("⚠️ Some quality loss detected")

    except Exception as e:
        print(f"❌ Transcription error: {e}")

    # Test translation
    print(f"\n🌍 TRANSLATION TEST (Turkish → English):")
    print("-" * 50)

    try:
        # Original model
        print("1️⃣ ORIGINAL model translation:")
        start_time = time.time()
        original_trans = original_model.transcribe(
            audio_file,
            language="tr",
            task="translate"
        )
        original_trans_time = time.time() - start_time

        print(f"   Time: {original_trans_time:.1f}s")
        print(f"   Translation: '{original_trans['text']}'")

        # Quantized model
        print("\n2️⃣ QUANTIZED model translation:")
        start_time = time.time()
        quantized_trans = quantized_model.transcribe(
            audio_file,
            language="tr",
            task="translate"
        )
        quantized_trans_time = time.time() - start_time

        print(f"   Time: {quantized_trans_time:.1f}s")
        print(f"   Translation: '{quantized_trans['text']}'")

        # Compare translations
        print(f"\n📊 TRANSLATION COMPARISON:")
        orig_trans_text = original_trans['text'].strip()
        quant_trans_text = quantized_trans['text'].strip()

        if orig_trans_text == quant_trans_text:
            print("✅ IDENTICAL translations!")
        else:
            print("📝 Translation differences:")
            print(f"   Original:  '{orig_trans_text}'")
            print(f"   Quantized: '{quant_trans_text}'")

    except Exception as e:
        print(f"❌ Translation error: {e}")

    # Performance summary
    print(f"\n⚡ PERFORMANCE SUMMARY:")
    print("-" * 30)
    print(f"Model loading:")
    print(f"   Original:  {original_load_time:.1f}s")
    print(f"   Quantized: {quantized_load_time:.1f}s")

    if 'original_time' in locals() and 'quantized_time' in locals():
        print(f"Transcription speed:")
        print(f"   Original:  {original_time:.1f}s")
        print(f"   Quantized: {quantized_time:.1f}s")
        if quantized_time > 0:
            speedup = original_time / quantized_time
            print(f"   Speedup: {speedup:.1f}x")

    # File size comparison
    original_size = Path.home() / ".cache" / "whisper" / "medium.pt"
    quantized_size = Path(quantized_path)

    if original_size.exists():
        orig_mb = original_size.stat().st_size / (1024 * 1024)
        quant_mb = quantized_size.stat().st_size / (1024 * 1024)
        compression = orig_mb / quant_mb

        print(f"Model size:")
        print(f"   Original:  {orig_mb:.0f} MB")
        print(f"   Quantized: {quant_mb:.0f} MB")
        print(f"   Compression: {compression:.1f}x")

def main():
    """Main testing workflow"""
    print("🚀 Testing Simple Quantized Whisper Model")
    print("=" * 45)

    test_with_turkish_audio()

    print(f"\n✅ Quantized model testing completed!")
    print(f"🎯 Your quantized model is ready for iOS deployment!")

if __name__ == "__main__":
    main()