#!/usr/bin/env python3
"""
Simple Direct Test: Quantized vs Original WhisperKit

Direct comparison of:
1. Our quantized CoreML encoder
2. Original WhisperKit AudioEncoder
3. Using real Turkish audio (fateh-1.m4a)

Usage:
    python simple_direct_test.py
"""

import coremltools as ct
import torch
import whisper
import numpy as np
from pathlib import Path
import time
import psutil
import os

def get_memory_mb():
    """Get current memory usage in MB"""
    process = psutil.Process(os.getpid())
    return process.memory_info().rss / (1024 * 1024)

def load_turkish_audio():
    """Load the Turkish audio file"""
    audio_file = "Resources/fateh-1.m4a"

    if not Path(audio_file).exists():
        print(f"❌ Audio file not found: {audio_file}")
        return None

    print(f"🎵 Loading Turkish audio: {audio_file}")

    # Load audio using whisper's method
    audio = whisper.load_audio(audio_file)

    # Convert to mel spectrogram
    mel = whisper.audio.log_mel_spectrogram(torch.from_numpy(audio))

    # Pad/trim to standard length
    target_length = 3000
    if mel.shape[-1] > target_length:
        mel = mel[:, :target_length]
    elif mel.shape[-1] < target_length:
        padding = target_length - mel.shape[-1]
        mel = torch.nn.functional.pad(mel, (0, padding))

    # Add batch dimension
    mel = mel.unsqueeze(0)

    print(f"✅ Audio loaded and converted to mel: {mel.shape}")
    return mel

def test_quantized_coreml():
    """Test our quantized CoreML encoder"""
    print("\n1️⃣ TESTING QUANTIZED COREML ENCODER")
    print("=" * 45)

    model_path = "whisper_encoder_quantized.mlpackage"

    if not Path(model_path).exists():
        print(f"❌ Quantized model not found: {model_path}")
        return None

    # Get file size
    if Path(model_path).is_dir():
        size = sum(f.stat().st_size for f in Path(model_path).rglob('*') if f.is_file())
    else:
        size = Path(model_path).stat().st_size
    file_size_mb = size / (1024 * 1024)

    print(f"📁 File size: {file_size_mb:.1f} MB")

    # Load Turkish audio
    mel_input = load_turkish_audio()
    if mel_input is None:
        return None

    # Test loading
    memory_before = get_memory_mb()
    print(f"💾 Memory before loading: {memory_before:.1f} MB")

    print("🔄 Loading quantized CoreML model...")
    start_time = time.time()
    model = ct.models.MLModel(model_path)
    load_time = time.time() - start_time

    memory_after_load = get_memory_mb()
    load_memory = memory_after_load - memory_before

    print(f"✅ Loaded in {load_time:.1f}s")
    print(f"💾 Memory after loading: {memory_after_load:.1f} MB")
    print(f"📈 Memory used for loading: {load_memory:.1f} MB")

    # Test inference
    print("🔄 Running inference on Turkish audio...")
    mel_numpy = mel_input.numpy()

    memory_before_inference = get_memory_mb()
    start_time = time.time()
    result = model.predict({"mel": mel_numpy})
    inference_time = time.time() - start_time
    memory_after_inference = get_memory_mb()

    inference_memory = memory_after_inference - memory_before_inference

    print(f"✅ Inference completed in {inference_time:.3f}s")
    print(f"💾 Memory during inference: {memory_after_inference:.1f} MB")
    print(f"📈 Memory used for inference: {inference_memory:.1f} MB")

    # Get output info
    output_key = list(result.keys())[0]
    output_shape = result[output_key].shape
    print(f"📤 Output shape: {output_shape}")

    return {
        'file_size': file_size_mb,
        'load_time': load_time,
        'load_memory': load_memory,
        'inference_time': inference_time,
        'total_memory': memory_after_inference,
        'inference_memory': inference_memory,
        'output_shape': output_shape
    }

def test_original_whisperkit():
    """Test original WhisperKit AudioEncoder"""
    print("\n2️⃣ TESTING ORIGINAL WHISPERKIT AUDIOENCODER")
    print("=" * 50)

    model_path = "../EnglishSubtitles/Models/openai_whisper-medium/AudioEncoder.mlmodelc"

    if not Path(model_path).exists():
        print(f"❌ Original model not found: {model_path}")
        return None

    # Get file size
    if Path(model_path).is_dir():
        size = sum(f.stat().st_size for f in Path(model_path).rglob('*') if f.is_file())
    else:
        size = Path(model_path).stat().st_size
    file_size_mb = size / (1024 * 1024)

    print(f"📁 File size: {file_size_mb:.1f} MB")

    # Load Turkish audio
    mel_input = load_turkish_audio()
    if mel_input is None:
        return None

    # Test loading
    memory_before = get_memory_mb()
    print(f"💾 Memory before loading: {memory_before:.1f} MB")

    print("🔄 Loading original WhisperKit AudioEncoder...")
    start_time = time.time()
    model = ct.models.MLModel(model_path)
    load_time = time.time() - start_time

    memory_after_load = get_memory_mb()
    load_memory = memory_after_load - memory_before

    print(f"✅ Loaded in {load_time:.1f}s")
    print(f"💾 Memory after loading: {memory_after_load:.1f} MB")
    print(f"📈 Memory used for loading: {load_memory:.1f} MB")

    # Test inference with Turkish audio
    print("🔄 Running inference on Turkish audio...")
    mel_numpy = mel_input.numpy()

    # Try different input names (WhisperKit might use different names)
    input_names = ["audio", "mel_spectrogram", "input", "logmel", "mel"]

    for input_name in input_names:
        try:
            memory_before_inference = get_memory_mb()
            start_time = time.time()
            result = model.predict({input_name: mel_numpy})
            inference_time = time.time() - start_time
            memory_after_inference = get_memory_mb()

            inference_memory = memory_after_inference - memory_before_inference

            print(f"✅ Inference completed in {inference_time:.3f}s (input: '{input_name}')")
            print(f"💾 Memory during inference: {memory_after_inference:.1f} MB")
            print(f"📈 Memory used for inference: {inference_memory:.1f} MB")

            # Get output info
            output_key = list(result.keys())[0]
            output_shape = result[output_key].shape
            print(f"📤 Output shape: {output_shape}")

            return {
                'file_size': file_size_mb,
                'load_time': load_time,
                'load_memory': load_memory,
                'inference_time': inference_time,
                'total_memory': memory_after_inference,
                'inference_memory': inference_memory,
                'output_shape': output_shape
            }

        except Exception as e:
            if "not found" in str(e).lower():
                continue
            else:
                print(f"❌ Failed with input '{input_name}': {e}")
                continue

    print("❌ Could not find correct input name for original model")
    return None

def compare_results(quantized_results, original_results):
    """Direct comparison of results"""
    print("\n📊 DIRECT COMPARISON")
    print("=" * 40)

    if not quantized_results or not original_results:
        print("❌ Cannot compare - missing results")
        return

    print(f"{'Metric':<20} {'Quantized':<12} {'Original':<12} {'Improvement':<12}")
    print("-" * 60)

    # File size
    q_size = quantized_results['file_size']
    o_size = original_results['file_size']
    size_ratio = o_size / q_size if q_size > 0 else 0
    print(f"{'File Size (MB)':<20} {q_size:<12.1f} {o_size:<12.1f} {size_ratio:<12.1f}x")

    # Load time
    q_load = quantized_results['load_time']
    o_load = original_results['load_time']
    load_ratio = o_load / q_load if q_load > 0 else 0
    print(f"{'Load Time (s)':<20} {q_load:<12.1f} {o_load:<12.1f} {load_ratio:<12.1f}x")

    # Load memory
    q_load_mem = quantized_results['load_memory']
    o_load_mem = original_results['load_memory']
    load_mem_ratio = o_load_mem / q_load_mem if q_load_mem > 0 else 0
    print(f"{'Load Memory (MB)':<20} {q_load_mem:<12.1f} {o_load_mem:<12.1f} {load_mem_ratio:<12.1f}x")

    # Inference time
    q_inf = quantized_results['inference_time']
    o_inf = original_results['inference_time']
    inf_ratio = o_inf / q_inf if q_inf > 0 else 0
    print(f"{'Inference (s)':<20} {q_inf:<12.3f} {o_inf:<12.3f} {inf_ratio:<12.1f}x")

    # Total memory
    q_mem = quantized_results['total_memory']
    o_mem = original_results['total_memory']
    mem_ratio = o_mem / q_mem if q_mem > 0 else 0
    print(f"{'Total Memory (MB)':<20} {q_mem:<12.1f} {o_mem:<12.1f} {mem_ratio:<12.1f}x")

    print(f"\n🎯 SUMMARY:")
    if size_ratio > 1:
        print(f"✅ File size: {size_ratio:.1f}x smaller")
    if mem_ratio > 1:
        print(f"✅ Memory usage: {mem_ratio:.1f}x less")
    if inf_ratio > 1:
        print(f"⚡ Inference: {inf_ratio:.1f}x faster")

def main():
    """Simple direct test"""
    print("🚀 SIMPLE DIRECT TEST: Quantized vs Original WhisperKit")
    print("=" * 60)
    print("🎵 Testing with Turkish audio: fateh-1.m4a")
    print("🎯 Measuring: file size, load time, memory usage, inference speed")

    # Test both models
    quantized_results = test_quantized_coreml()
    original_results = test_original_whisperkit()

    # Compare results
    compare_results(quantized_results, original_results)

    print(f"\n✅ Direct test completed!")

if __name__ == "__main__":
    main()