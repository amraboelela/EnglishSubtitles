#!/usr/bin/env python3
"""
Test Original Properly Quantized Model

Compare whisper_medium_properly_quantized.pth with the simple version
and original model.
"""

import torch
import whisper
import numpy as np
from pathlib import Path
import time

def load_properly_quantized_model(model_path):
    """Load the original properly quantized model"""
    print(f"🔄 Loading properly quantized model: {model_path}")

    try:
        # Fix numpy loading issue
        torch.serialization.add_safe_globals([np.core.multiarray._reconstruct])
        quantized_state = torch.load(model_path, map_location='cpu', weights_only=False)

        # Load original model architecture
        original_model = whisper.load_model("medium")

        # Dequantize weights
        dequantized_state = {}
        for name, data in quantized_state.items():
            if 'original' in data:
                # Original tensor (not quantized)
                dequantized_state[name] = torch.from_numpy(data['weights'])
            else:
                # Dequantize int8 back to float32
                weights = data['weights']
                scale = data['scale']
                zero_point = data['zero_point']

                # Dequantize: float_weights = (int8_weights - zero_point) * scale
                dequantized = (weights.astype(np.float32) - zero_point) * scale
                dequantized_state[name] = torch.from_numpy(dequantized)

        # Load dequantized weights into model
        original_model.load_state_dict(dequantized_state)
        print("✅ Properly quantized model loaded successfully!")

        return original_model

    except Exception as e:
        print(f"❌ Error loading properly quantized model: {e}")
        return None

def load_simple_quantized_model(model_path):
    """Load the simple quantized model"""
    print(f"🔄 Loading simple quantized model: {model_path}")

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

                dequantized = (quantized_weights.astype(np.float32) - zero_point) * scale
                dequantized_dict[name] = torch.from_numpy(dequantized)
            else:
                # Convert float16 back to float32 or keep as-is
                param_data = quantized_dict[name]
                if param_data.dtype == torch.float16:
                    dequantized_dict[name] = param_data.float()
                else:
                    dequantized_dict[name] = param_data

    # Load dequantized weights into model
    original_model.load_state_dict(dequantized_dict)
    print("✅ Simple quantized model loaded successfully!")

    return original_model

def test_all_models():
    """Test all three models: original, properly quantized, simple quantized"""
    print("🎯 Testing All Models: Original vs Properly Quantized vs Simple Quantized")
    print("=" * 80)

    audio_file = "Resources/fateh-1.m4a"
    if not Path(audio_file).exists():
        print(f"❌ Audio file not found: {audio_file}")
        return

    # Check model files
    properly_quantized_path = "whisper_medium_properly_quantized.pth"
    simple_quantized_path = "whisper_quantized_simple.pth"

    if not Path(properly_quantized_path).exists():
        print(f"❌ Properly quantized model not found: {properly_quantized_path}")
        return

    if not Path(simple_quantized_path).exists():
        print(f"❌ Simple quantized model not found: {simple_quantized_path}")
        return

    print(f"🎵 Testing with: {audio_file}")

    # Load all models
    print("\n📥 Loading all models...")
    models = {}

    print("1️⃣ Loading ORIGINAL model...")
    start_time = time.time()
    models['original'] = whisper.load_model("medium")
    models['original_load_time'] = time.time() - start_time
    print(f"   ✓ Loaded in {models['original_load_time']:.1f}s")

    print("2️⃣ Loading PROPERLY QUANTIZED model...")
    start_time = time.time()
    models['properly_quantized'] = load_properly_quantized_model(properly_quantized_path)
    models['properly_quantized_load_time'] = time.time() - start_time
    if models['properly_quantized']:
        print(f"   ✓ Loaded in {models['properly_quantized_load_time']:.1f}s")

    print("3️⃣ Loading SIMPLE QUANTIZED model...")
    start_time = time.time()
    models['simple_quantized'] = load_simple_quantized_model(simple_quantized_path)
    models['simple_quantized_load_time'] = time.time() - start_time
    print(f"   ✓ Loaded in {models['simple_quantized_load_time']:.1f}s")

    # Test transcription
    print(f"\n🔤 TRANSCRIPTION TEST (Turkish):")
    print("-" * 60)

    results = {}

    for model_name in ['original', 'properly_quantized', 'simple_quantized']:
        model = models[model_name]
        if model is None:
            continue

        print(f"\n{model_name.upper().replace('_', ' ')}:")
        try:
            start_time = time.time()
            result = model.transcribe(
                audio_file,
                language="tr",
                task="transcribe"
            )
            inference_time = time.time() - start_time

            results[model_name] = {
                'transcription': result['text'].strip(),
                'time': inference_time
            }

            print(f"   Time: {inference_time:.1f}s")
            print(f"   Text: '{result['text']}'")

        except Exception as e:
            print(f"   ❌ Error: {e}")
            results[model_name] = None

    # Compare transcriptions
    print(f"\n📊 TRANSCRIPTION COMPARISON:")
    print("-" * 40)

    if 'original' in results and results['original']:
        original_text = results['original']['transcription']
        print(f"Original:           '{original_text}'")

        for model_name in ['properly_quantized', 'simple_quantized']:
            if model_name in results and results[model_name]:
                model_text = results[model_name]['transcription']
                print(f"{model_name.replace('_', ' ').title():15}: '{model_text}'")

                if original_text == model_text:
                    print(f"                    ✅ IDENTICAL to original!")
                else:
                    # Calculate similarity
                    orig_words = set(original_text.lower().split())
                    model_words = set(model_text.lower().split())
                    if orig_words | model_words:
                        similarity = len(orig_words & model_words) / len(orig_words | model_words) * 100
                        print(f"                    📊 {similarity:.1f}% similarity")

    # Test translation
    print(f"\n🌍 TRANSLATION TEST (Turkish → English):")
    print("-" * 60)

    translations = {}

    for model_name in ['original', 'properly_quantized', 'simple_quantized']:
        model = models[model_name]
        if model is None:
            continue

        print(f"\n{model_name.upper().replace('_', ' ')}:")
        try:
            start_time = time.time()
            result = model.transcribe(
                audio_file,
                language="tr",
                task="translate"
            )
            translate_time = time.time() - start_time

            translations[model_name] = {
                'translation': result['text'].strip(),
                'time': translate_time
            }

            print(f"   Time: {translate_time:.1f}s")
            print(f"   Translation: '{result['text']}'")

        except Exception as e:
            print(f"   ❌ Error: {e}")
            translations[model_name] = None

    # Performance summary
    print(f"\n⚡ PERFORMANCE SUMMARY:")
    print("-" * 40)

    print("Loading times:")
    print(f"   Original:           {models['original_load_time']:.1f}s")
    if models['properly_quantized']:
        print(f"   Properly Quantized: {models['properly_quantized_load_time']:.1f}s")
    print(f"   Simple Quantized:   {models['simple_quantized_load_time']:.1f}s")

    if results['original']:
        print("Transcription speed:")
        print(f"   Original:           {results['original']['time']:.1f}s")
        if 'properly_quantized' in results and results['properly_quantized']:
            speedup = results['original']['time'] / results['properly_quantized']['time']
            print(f"   Properly Quantized: {results['properly_quantized']['time']:.1f}s ({speedup:.1f}x)")
        if 'simple_quantized' in results and results['simple_quantized']:
            speedup = results['original']['time'] / results['simple_quantized']['time']
            print(f"   Simple Quantized:   {results['simple_quantized']['time']:.1f}s ({speedup:.1f}x)")

    # File sizes
    print("\nModel sizes:")
    original_cache = Path.home() / ".cache" / "whisper" / "medium.pt"
    if original_cache.exists():
        orig_size = original_cache.stat().st_size / (1024 * 1024)
        print(f"   Original:           {orig_size:.0f} MB")

        properly_size = Path(properly_quantized_path).stat().st_size / (1024 * 1024)
        simple_size = Path(simple_quantized_path).stat().st_size / (1024 * 1024)

        print(f"   Properly Quantized: {properly_size:.0f} MB ({orig_size/properly_size:.1f}x compression)")
        print(f"   Simple Quantized:   {simple_size:.0f} MB ({orig_size/simple_size:.1f}x compression)")

def main():
    """Main testing workflow"""
    print("🚀 Comprehensive Quantized Model Comparison")
    print("=" * 50)

    test_all_models()

    print(f"\n✅ Comprehensive testing completed!")
    print(f"🎯 Compare the results to choose the best quantized model!")

if __name__ == "__main__":
    main()