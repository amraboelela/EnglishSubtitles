#!/usr/bin/env python3
"""
CoreML Quantization - Working Version

Uses the correct CoreML 9.0 APIs for quantization.

Usage:
    python coreml_quantization_working.py
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

def create_quantized_coreml_models():
    """Create both float16 and int8 quantized CoreML models"""
    print("🔄 Loading original Whisper medium model...")
    memory_start = get_memory_mb()

    # Load original model
    model = whisper.load_model("medium")
    encoder = model.encoder
    encoder.eval()

    print(f"💾 Memory after loading: {get_memory_mb():.1f} MB")

    # Create sample input for tracing
    print("🔄 Creating sample input for tracing...")
    sample_mel = torch.randn(1, 80, 3000)

    # Trace the encoder
    print("🔄 Tracing encoder model...")
    traced_encoder = torch.jit.trace(encoder, sample_mel)

    print("🔄 Converting to CoreML with float32...")
    start_time = time.time()

    # Convert to CoreML with float32 first (for quantization)
    base_model = ct.convert(
        traced_encoder,
        inputs=[ct.TensorType(name="mel", shape=sample_mel.shape)],
        outputs=[ct.TensorType(name="encoder_output")],
        compute_units=ct.ComputeUnit.CPU_AND_NE,
        compute_precision=ct.precision.FLOAT32,  # Start with float32
        minimum_deployment_target=ct.target.iOS16
    )

    conversion_time = time.time() - start_time
    print(f"✅ Base CoreML conversion completed in {conversion_time:.1f}s")

    models_created = []

    # 1. Create float16 model
    print("🔄 Creating float16 model...")
    float16_model = ct.convert(
        traced_encoder,
        inputs=[ct.TensorType(name="mel", shape=sample_mel.shape)],
        outputs=[ct.TensorType(name="encoder_output")],
        compute_units=ct.ComputeUnit.CPU_AND_NE,
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.iOS16
    )

    float16_path = "whisper_encoder_float16.mlpackage"
    float16_model.save(float16_path)
    float16_size = sum(f.stat().st_size for f in Path(float16_path).rglob('*') if f.is_file()) / (1024 * 1024)
    print(f"📁 Float16 model: {float16_size:.1f} MB")
    models_created.append((float16_path, float16_size, "Float16"))

    # 2. Create int8 quantized model
    print("🔄 Creating int8 quantized model...")
    try:
        # Use the correct API for int8 quantization
        int8_model = ct.optimize.coreml.linear_quantize_weights(
            base_model,
            config=None,  # Use default config
        )

        int8_path = "whisper_encoder_int8.mlpackage"
        int8_model.save(int8_path)
        int8_size = sum(f.stat().st_size for f in Path(int8_path).rglob('*') if f.is_file()) / (1024 * 1024)
        print(f"📁 Int8 model: {int8_size:.1f} MB")
        models_created.append((int8_path, int8_size, "Int8"))

    except Exception as e:
        print(f"❌ Int8 quantization failed: {e}")

    # 3. Try palettization (another form of compression)
    print("🔄 Creating palettized model...")
    try:
        palettized_model = ct.optimize.coreml.palettize_weights(
            base_model,
            config=None,  # Use default config
        )

        palette_path = "whisper_encoder_palettized.mlpackage"
        palettized_model.save(palette_path)
        palette_size = sum(f.stat().st_size for f in Path(palette_path).rglob('*') if f.is_file()) / (1024 * 1024)
        print(f"📁 Palettized model: {palette_size:.1f} MB")
        models_created.append((palette_path, palette_size, "Palettized"))

    except Exception as e:
        print(f"❌ Palettization failed: {e}")

    memory_end = get_memory_mb()
    print(f"💾 Total memory used: {memory_end - memory_start:.1f} MB")

    return models_created

def test_models(models_created):
    """Test all created models"""
    print("\n🧪 TESTING MODELS")
    print("=" * 40)

    sample_input = np.random.randn(1, 80, 3000).astype(np.float32)

    for model_path, size_mb, model_type in models_created:
        if not Path(model_path).exists():
            print(f"⚠️ {model_type} model not found")
            continue

        print(f"\n🔄 Testing {model_type} model...")

        try:
            model = ct.models.MLModel(model_path)

            # Benchmark inference
            start_time = time.time()
            result = model.predict({"mel": sample_input})
            inference_time = time.time() - start_time

            output_key = list(result.keys())[0]
            output_shape = result[output_key].shape

            print(f"✅ {model_type:12}: {inference_time:.3f}s, {size_mb:.1f}MB, shape: {output_shape}")

        except Exception as e:
            print(f"❌ {model_type} test failed: {e}")

def compare_with_original(models_created):
    """Compare with original CoreML model"""
    print("\n📊 SIZE COMPARISON")
    print("=" * 40)

    # Original model
    original_path = "../EnglishSubtitles/Models/openai_whisper-medium/AudioEncoder.mlmodelc"
    original_size_mb = 0
    if Path(original_path).exists():
        size = sum(f.stat().st_size for f in Path(original_path).rglob('*') if f.is_file())
        original_size_mb = size / (1024 * 1024)
        print(f"{'Original':12}: {original_size_mb:.1f} MB")
    else:
        print("❌ Original model not found")

    # Our models
    for model_path, size_mb, model_type in models_created:
        if Path(model_path).exists():
            print(f"{model_type:12}: {size_mb:.1f} MB", end="")

            if original_size_mb > 0:
                if size_mb < original_size_mb:
                    compression = original_size_mb / size_mb
                    savings = original_size_mb - size_mb
                    print(f" ({compression:.1f}x smaller, {savings:.1f}MB saved)")
                else:
                    increase = size_mb / original_size_mb
                    print(f" ({increase:.1f}x larger)")
            else:
                print()
        else:
            print(f"{model_type:12}: Not found")

def main():
    """Main quantization workflow"""
    print("🚀 CoreML Quantization - Working Version")
    print("=" * 50)

    # Create quantized models
    models_created = create_quantized_coreml_models()

    if models_created:
        # Test the models
        test_models(models_created)

        # Compare with original
        compare_with_original(models_created)

        print(f"\n✅ CoreML quantization completed!")
        print(f"📁 Models created: {len(models_created)}")

        # Summary
        smallest_model = min(models_created, key=lambda x: x[1])
        print(f"🏆 Smallest model: {smallest_model[2]} ({smallest_model[1]:.1f} MB)")

    else:
        print(f"\n❌ No models were created successfully")

if __name__ == "__main__":
    main()