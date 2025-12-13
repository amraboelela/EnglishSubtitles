#!/usr/bin/env python3
"""
Test CoreML Quantized Encoder

Test the converted CoreML encoder to measure:
1. File size
2. Memory usage during inference
3. Performance vs original

Usage:
    python test_coreml_encoder.py
"""

import coremltools as ct
import numpy as np
import torch
import whisper
from pathlib import Path
import time
import psutil
import os

def get_memory_usage():
    """Get current memory usage in MB"""
    process = psutil.Process(os.getpid())
    return process.memory_info().rss / (1024 * 1024)

def analyze_coreml_model():
    """Analyze the CoreML model file"""
    print("📊 Analyzing CoreML Quantized Encoder")
    print("=" * 45)

    model_path = "whisper_encoder_quantized.mlpackage"

    if not Path(model_path).exists():
        print(f"❌ Model not found: {model_path}")
        print("💡 Run: python convert_to_coreml.py first")
        return None

    # Get file size
    if Path(model_path).is_dir():
        # .mlpackage is a directory
        total_size = sum(f.stat().st_size for f in Path(model_path).rglob('*') if f.is_file())
    else:
        total_size = Path(model_path).stat().st_size

    file_size_mb = total_size / (1024 * 1024)

    print(f"📁 Model file: {model_path}")
    print(f"💾 File size: {file_size_mb:.1f} MB")

    return model_path, file_size_mb

def test_coreml_inference():
    """Test CoreML encoder inference and memory usage"""
    print(f"\n🧪 Testing CoreML Inference & Memory Usage")
    print("-" * 45)

    model_path = "whisper_encoder_quantized.mlpackage"

    try:
        # Measure memory before loading
        memory_before = get_memory_usage()
        print(f"💾 Memory before loading: {memory_before:.1f} MB")

        # Load CoreML model
        print("🔄 Loading CoreML model...")
        start_time = time.time()
        coreml_model = ct.models.MLModel(model_path)
        load_time = time.time() - start_time

        memory_after_load = get_memory_usage()
        memory_used_loading = memory_after_load - memory_before

        print(f"✅ Model loaded in {load_time:.1f}s")
        print(f"💾 Memory after loading: {memory_after_load:.1f} MB")
        print(f"📈 Memory used for loading: {memory_used_loading:.1f} MB")

        # Create test input (mel spectrogram)
        print(f"\n🎯 Preparing test input...")
        batch_size = 1
        n_mels = 80
        seq_len = 3000
        dummy_input = np.random.randn(batch_size, n_mels, seq_len).astype(np.float32)

        print(f"📊 Input shape: {dummy_input.shape}")

        # Run inference multiple times to measure memory usage
        print(f"\n🔄 Running inference tests...")

        inference_times = []
        memory_peaks = []

        for i in range(5):
            memory_before_inference = get_memory_usage()

            start_time = time.time()
            result = coreml_model.predict({"mel": dummy_input})
            inference_time = time.time() - start_time

            memory_after_inference = get_memory_usage()
            memory_peak = max(memory_before_inference, memory_after_inference)

            inference_times.append(inference_time)
            memory_peaks.append(memory_peak)

            if i == 0:
                print(f"   Run {i+1}: {inference_time:.3f}s, Memory: {memory_after_inference:.1f} MB")
                # Print output info for first run
                output_key = list(result.keys())[0]
                output_shape = result[output_key].shape
                print(f"   📤 Output shape: {output_shape}")
            else:
                print(f"   Run {i+1}: {inference_time:.3f}s, Memory: {memory_after_inference:.1f} MB")

        # Calculate averages
        avg_inference_time = sum(inference_times) / len(inference_times)
        avg_memory_peak = sum(memory_peaks) / len(memory_peaks)
        max_memory_used = max(memory_peaks) - memory_before

        print(f"\n📊 Inference Results:")
        print(f"   Average inference time: {avg_inference_time:.3f}s")
        print(f"   Average memory during inference: {avg_memory_peak:.1f} MB")
        print(f"   Peak memory increase: {max_memory_used:.1f} MB")

        return {
            'load_time': load_time,
            'memory_for_loading': memory_used_loading,
            'avg_inference_time': avg_inference_time,
            'avg_memory_usage': avg_memory_peak,
            'memory_increase': max_memory_used
        }

    except Exception as e:
        print(f"❌ CoreML inference failed: {e}")
        return None

def compare_with_pytorch_encoder():
    """Compare with PyTorch encoder memory usage"""
    print(f"\n🔄 Comparing with PyTorch Encoder")
    print("-" * 40)

    try:
        # Load original PyTorch model
        memory_before = get_memory_usage()
        print(f"💾 Memory before PyTorch loading: {memory_before:.1f} MB")

        print("🔄 Loading PyTorch Whisper model...")
        start_time = time.time()
        model = whisper.load_model("medium")
        encoder = model.encoder
        encoder.eval()
        load_time = time.time() - start_time

        memory_after_load = get_memory_usage()
        memory_used_loading = memory_after_load - memory_before

        print(f"✅ PyTorch model loaded in {load_time:.1f}s")
        print(f"💾 Memory after loading: {memory_after_load:.1f} MB")
        print(f"📈 Memory used for loading: {memory_used_loading:.1f} MB")

        # Test PyTorch inference
        print(f"\n🧪 Testing PyTorch encoder inference...")

        # Create test input
        dummy_input = torch.randn(1, 80, 3000)

        inference_times = []
        memory_peaks = []

        with torch.no_grad():
            for i in range(5):
                memory_before_inference = get_memory_usage()

                start_time = time.time()
                result = encoder(dummy_input)
                inference_time = time.time() - start_time

                memory_after_inference = get_memory_usage()
                memory_peak = max(memory_before_inference, memory_after_inference)

                inference_times.append(inference_time)
                memory_peaks.append(memory_peak)

                if i == 0:
                    print(f"   Run {i+1}: {inference_time:.3f}s, Memory: {memory_after_inference:.1f} MB")
                    print(f"   📤 Output shape: {result.shape}")
                else:
                    print(f"   Run {i+1}: {inference_time:.3f}s, Memory: {memory_after_inference:.1f} MB")

        avg_inference_time = sum(inference_times) / len(inference_times)
        avg_memory_peak = sum(memory_peaks) / len(memory_peaks)
        max_memory_used = max(memory_peaks) - memory_before

        print(f"\n📊 PyTorch Results:")
        print(f"   Average inference time: {avg_inference_time:.3f}s")
        print(f"   Average memory during inference: {avg_memory_peak:.1f} MB")
        print(f"   Peak memory increase: {max_memory_used:.1f} MB")

        return {
            'load_time': load_time,
            'memory_for_loading': memory_used_loading,
            'avg_inference_time': avg_inference_time,
            'avg_memory_usage': avg_memory_peak,
            'memory_increase': max_memory_used
        }

    except Exception as e:
        print(f"❌ PyTorch comparison failed: {e}")
        return None

def compare_results(coreml_results, pytorch_results):
    """Compare CoreML vs PyTorch results"""
    print(f"\n📊 COMPARISON SUMMARY")
    print("=" * 50)

    if not coreml_results or not pytorch_results:
        print("❌ Cannot compare - missing results")
        return

    print(f"{'Metric':<25} {'CoreML':<12} {'PyTorch':<12} {'Improvement':<12}")
    print("-" * 65)

    # Loading time
    coreml_load = coreml_results['load_time']
    pytorch_load = pytorch_results['load_time']
    load_improvement = pytorch_load / coreml_load if coreml_load > 0 else 0
    print(f"{'Load time (s)':<25} {coreml_load:<12.1f} {pytorch_load:<12.1f} {load_improvement:<12.1f}x")

    # Memory for loading
    coreml_mem_load = coreml_results['memory_for_loading']
    pytorch_mem_load = pytorch_results['memory_for_loading']
    mem_load_improvement = pytorch_mem_load / coreml_mem_load if coreml_mem_load > 0 else 0
    print(f"{'Loading memory (MB)':<25} {coreml_mem_load:<12.1f} {pytorch_mem_load:<12.1f} {mem_load_improvement:<12.1f}x")

    # Inference time
    coreml_inf = coreml_results['avg_inference_time']
    pytorch_inf = pytorch_results['avg_inference_time']
    inf_improvement = pytorch_inf / coreml_inf if coreml_inf > 0 else 0
    print(f"{'Inference time (s)':<25} {coreml_inf:<12.3f} {pytorch_inf:<12.3f} {inf_improvement:<12.1f}x")

    # Memory usage
    coreml_mem = coreml_results['avg_memory_usage']
    pytorch_mem = pytorch_results['avg_memory_usage']
    mem_improvement = pytorch_mem / coreml_mem if coreml_mem > 0 else 0
    print(f"{'Memory usage (MB)':<25} {coreml_mem:<12.1f} {pytorch_mem:<12.1f} {mem_improvement:<12.1f}x")

    # Memory increase
    coreml_mem_inc = coreml_results['memory_increase']
    pytorch_mem_inc = pytorch_results['memory_increase']
    mem_inc_improvement = pytorch_mem_inc / coreml_mem_inc if coreml_mem_inc > 0 else 0
    print(f"{'Memory increase (MB)':<25} {coreml_mem_inc:<12.1f} {pytorch_mem_inc:<12.1f} {mem_inc_improvement:<12.1f}x")

    print(f"\n🎯 KEY INSIGHTS:")
    if mem_improvement > 1.0:
        print(f"✅ CoreML uses {mem_improvement:.1f}x LESS memory - Great for iOS!")
    else:
        print(f"⚠️ CoreML uses {1/mem_improvement:.1f}x MORE memory")

    if inf_improvement > 1.0:
        print(f"⚡ CoreML is {inf_improvement:.1f}x FASTER")
    else:
        print(f"🐌 CoreML is {1/inf_improvement:.1f}x slower")

def main():
    """Main testing workflow"""
    print("🚀 Testing CoreML Quantized Encoder")
    print("=" * 40)

    # Analyze the model file
    model_info = analyze_coreml_model()
    if not model_info:
        return

    model_path, file_size = model_info

    # Test CoreML inference
    coreml_results = test_coreml_inference()

    # Compare with PyTorch
    pytorch_results = compare_with_pytorch_encoder()

    # Compare results
    compare_results(coreml_results, pytorch_results)

    print(f"\n✅ CoreML testing completed!")
    print(f"🎯 This shows if quantization + CoreML saves memory for iOS!")

if __name__ == "__main__":
    main()