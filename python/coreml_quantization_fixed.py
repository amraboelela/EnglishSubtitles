#!/usr/bin/env python3
"""
CoreML Native Quantization - Fixed Version

Uses the correct CoreML 7+ quantization APIs that work with MLProgram format.
This avoids the PyTorch quantization → CoreML conversion issues.

Usage:
    python coreml_quantization_fixed.py
"""

import torch
import whisper
import numpy as np
import coremltools as ct
from pathlib import Path
import psutil
import os
import time

def get_memory_mb():
    """Get current memory usage in MB"""
    process = psutil.Process(os.getpid())
    return process.memory_info().rss / (1024 * 1024)

def create_coreml_model_with_quantization():
    """Create CoreML model with built-in quantization using newer APIs"""
    print("🔄 Loading original Whisper medium model...")
    memory_start = get_memory_mb()

    # Load original model
    model = whisper.load_model("medium")
    encoder = model.encoder
    encoder.eval()

    print(f"💾 Memory after loading: {get_memory_mb():.1f} MB")

    # Create sample input for tracing
    print("🔄 Creating sample input for tracing...")
    sample_mel = torch.randn(1, 80, 3000)  # Typical mel spectrogram shape

    # Trace the encoder
    print("🔄 Tracing encoder model...")
    traced_encoder = torch.jit.trace(encoder, sample_mel)

    print("🔄 Converting to CoreML with float16...")
    start_time = time.time()

    # Convert to CoreML with float16 first
    coreml_model = ct.convert(
        traced_encoder,
        inputs=[ct.TensorType(name="mel", shape=sample_mel.shape)],
        outputs=[ct.TensorType(name="encoder_output")],
        compute_units=ct.ComputeUnit.CPU_AND_NE,
        compute_precision=ct.precision.FLOAT16,  # Use float16
        minimum_deployment_target=ct.target.iOS16
    )

    conversion_time = time.time() - start_time
    print(f"✅ CoreML conversion completed in {conversion_time:.1f}s")

    # Save the float16 model first
    float16_path = "whisper_encoder_float16.mlpackage"
    print(f"💾 Saving float16 model to {float16_path}...")
    coreml_model.save(float16_path)

    # Get float16 size
    size = sum(f.stat().st_size for f in Path(float16_path).rglob('*') if f.is_file())
    float16_size_mb = size / (1024 * 1024)
    print(f"📁 Float16 model: {float16_size_mb:.1f} MB")

    # Now apply int8 quantization using the correct API
    print("🔄 Applying int8 quantization...")
    try:
        # Use the newer quantization API that works with MLProgram
        quantized_model = ct.optimize.coreml.linear_quantize_weights(
            coreml_model,
            mode="linear_symmetric",  # or "linear" for asymmetric
            dtype=np.int8
        )

        # Save the quantized model
        quantized_path = "whisper_encoder_int8_quantized.mlpackage"
        print(f"💾 Saving quantized CoreML model to {quantized_path}...")
        quantized_model.save(quantized_path)

        # Get quantized size
        size = sum(f.stat().st_size for f in Path(quantized_path).rglob('*') if f.is_file())
        quantized_size_mb = size / (1024 * 1024)

        print(f"📁 Quantized model saved: {quantized_size_mb:.1f} MB")

        memory_end = get_memory_mb()
        print(f"💾 Memory used: {memory_end - memory_start:.1f} MB")

        return quantized_path, quantized_size_mb, float16_path, float16_size_mb

    except Exception as e:
        print(f"❌ Int8 quantization failed: {e}")
        print(f"💡 Returning float16 model instead")
        return float16_path, float16_size_mb, float16_path, float16_size_mb

def test_quantized_models():
    """Test both float16 and int8 models"""
    models_to_test = [
        ("whisper_encoder_float16.mlpackage", "Float16"),
        ("whisper_encoder_int8_quantized.mlpackage", "Int8 Quantized")
    ]

    for model_path, model_name in models_to_test:
        if not Path(model_path).exists():
            print(f"⚠️ {model_name} model not found: {model_path}")
            continue

        print(f"\n🧪 Testing {model_name} model...")

        try:
            # Load the model
            print(f"🔄 Loading {model_name} CoreML model...")
            model = ct.models.MLModel(model_path)

            # Test with sample data
            print("🔄 Testing inference...")
            sample_input = np.random.randn(1, 80, 3000).astype(np.float32)

            start_time = time.time()
            result = model.predict({"mel": sample_input})
            inference_time = time.time() - start_time

            # Get output info
            output_key = list(result.keys())[0]
            output_shape = result[output_key].shape

            print(f"✅ {model_name} inference: {inference_time:.3f}s")
            print(f"📤 Output shape: {output_shape}")

        except Exception as e:
            print(f"❌ {model_name} test failed: {e}")

def compare_with_original():
    """Compare with original CoreML model"""
    print("\n📊 SIZE COMPARISON")
    print("=" * 40)

    # Original model
    original_path = "../EnglishSubtitles/Models/openai_whisper-medium/AudioEncoder.mlmodelc"
    original_size_mb = 0
    if Path(original_path).exists():
        size = sum(f.stat().st_size for f in Path(original_path).rglob('*') if f.is_file())
        original_size_mb = size / (1024 * 1024)
        print(f"Original AudioEncoder: {original_size_mb:.1f} MB")
    else:
        print("❌ Original model not found")

    # Our models
    models = [
        ("whisper_encoder_float16.mlpackage", "Float16"),
        ("whisper_encoder_int8_quantized.mlpackage", "Int8 Quantized")
    ]

    for model_path, model_name in models:
        if Path(model_path).exists():
            size = sum(f.stat().st_size for f in Path(model_path).rglob('*') if f.is_file())
            size_mb = size / (1024 * 1024)
            print(f"{model_name:15}: {size_mb:.1f} MB", end="")

            if original_size_mb > 0:
                compression = original_size_mb / size_mb
                savings = original_size_mb - size_mb
                print(f" ({compression:.1f}x smaller, {savings:.1f} MB saved)")
            else:
                print()
        else:
            print(f"{model_name:15}: Not found")

def main():
    """Main quantization workflow"""
    print("🚀 CoreML Native Quantization (Fixed)")
    print("=" * 50)

    # Create quantized models
    quantized_path, quantized_size, float16_path, float16_size = create_coreml_model_with_quantization()

    # Test the models
    test_quantized_models()

    # Compare with original
    compare_with_original()

    print(f"\n✅ CoreML quantization completed!")
    print(f"📁 Float16 model: {float16_path} ({float16_size:.1f} MB)")
    if quantized_path != float16_path:
        print(f"📁 Int8 model: {quantized_path} ({quantized_size:.1f} MB)")

if __name__ == "__main__":
    main()