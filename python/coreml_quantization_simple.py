#!/usr/bin/env python3
"""
CoreML Quantization - Simple Version

Focus on what actually works - float16 and proper configuration.

Usage:
    python coreml_quantization_simple.py
"""

import torch
import whisper
import numpy as np
import coremltools as ct
from pathlib import Path
import time

def create_float16_coreml():
    """Create float16 CoreML model - this is the most reliable quantization"""
    print("🔄 Loading original Whisper medium model...")
    model = whisper.load_model("medium")
    encoder = model.encoder
    encoder.eval()

    print("🔄 Creating sample input for tracing...")
    sample_mel = torch.randn(1, 80, 3000)

    print("🔄 Tracing encoder model...")
    traced_encoder = torch.jit.trace(encoder, sample_mel)

    print("🔄 Converting to CoreML with float16...")
    start_time = time.time()

    # Create float16 model (most reliable form of quantization)
    coreml_model = ct.convert(
        traced_encoder,
        inputs=[ct.TensorType(name="mel", shape=sample_mel.shape)],
        outputs=[ct.TensorType(name="encoder_output")],
        compute_units=ct.ComputeUnit.CPU_AND_NE,  # Use Neural Engine
        compute_precision=ct.precision.FLOAT16,   # This is quantization!
        minimum_deployment_target=ct.target.iOS16
    )

    conversion_time = time.time() - start_time
    print(f"✅ Float16 conversion completed in {conversion_time:.1f}s")

    # Save the model
    output_path = "whisper_encoder_quantized_float16.mlpackage"
    print(f"💾 Saving model to {output_path}...")
    coreml_model.save(output_path)

    # Get file size
    size = sum(f.stat().st_size for f in Path(output_path).rglob('*') if f.is_file())
    size_mb = size / (1024 * 1024)
    print(f"📁 Model size: {size_mb:.1f} MB")

    return output_path, size_mb, coreml_model

def try_int8_quantization(base_model):
    """Try different approaches for int8 quantization"""
    print("\n🔄 Attempting int8 quantization...")

    try:
        # Method 1: Use proper config
        from coremltools.optimize.coreml import OpLinearQuantizerConfig, OptimizationConfig

        # Create configuration
        op_config = OpLinearQuantizerConfig(
            mode="linear_symmetric",
            weight_threshold=512  # Only quantize weights with at least 512 elements
        )

        config = OptimizationConfig(
            global_config=op_config
        )

        print("🔄 Applying int8 quantization with explicit config...")
        quantized_model = ct.optimize.coreml.linear_quantize_weights(
            base_model,
            config=config
        )

        # Save the quantized model
        int8_path = "whisper_encoder_int8_quantized.mlpackage"
        quantized_model.save(int8_path)

        size = sum(f.stat().st_size for f in Path(int8_path).rglob('*') if f.is_file())
        size_mb = size / (1024 * 1024)
        print(f"✅ Int8 model created: {size_mb:.1f} MB")

        return int8_path, size_mb

    except Exception as e:
        print(f"❌ Int8 quantization failed: {e}")
        return None, 0

def test_performance(model_path, model_name):
    """Test model performance"""
    if not Path(model_path).exists():
        print(f"⚠️ {model_name} model not found")
        return

    print(f"\n🧪 Testing {model_name} performance...")

    try:
        model = ct.models.MLModel(model_path)
        sample_input = np.random.randn(1, 80, 3000).astype(np.float32)

        # Warmup
        model.predict({"mel": sample_input})

        # Benchmark
        times = []
        for i in range(5):
            start_time = time.time()
            result = model.predict({"mel": sample_input})
            inference_time = time.time() - start_time
            times.append(inference_time)

        avg_time = sum(times) / len(times)
        output_shape = result[list(result.keys())[0]].shape

        print(f"✅ {model_name:15}: {avg_time:.3f}s avg, shape: {output_shape}")

    except Exception as e:
        print(f"❌ {model_name} test failed: {e}")

def compare_models():
    """Compare all models we have"""
    print("\n📊 MODEL COMPARISON")
    print("=" * 50)

    models_to_check = [
        ("../EnglishSubtitles/Models/openai_whisper-medium/AudioEncoder.mlmodelc", "Original WhisperKit"),
        ("whisper_encoder_quantized_float16.mlpackage", "Our Float16"),
        ("whisper_encoder_int8_quantized.mlpackage", "Our Int8"),
    ]

    for model_path, model_name in models_to_check:
        if Path(model_path).exists():
            if Path(model_path).is_dir():
                size = sum(f.stat().st_size for f in Path(model_path).rglob('*') if f.is_file())
            else:
                size = Path(model_path).stat().st_size
            size_mb = size / (1024 * 1024)
            print(f"{model_name:20}: {size_mb:.1f} MB")
        else:
            print(f"{model_name:20}: Not found")

def main():
    """Main workflow"""
    print("🚀 CoreML Quantization - Simple & Reliable")
    print("=" * 50)

    # Create float16 model (this works reliably)
    float16_path, float16_size, base_model = create_float16_coreml()

    # Try int8 quantization
    int8_path, int8_size = try_int8_quantization(base_model)

    # Test performance
    test_performance(float16_path, "Float16")
    if int8_path:
        test_performance(int8_path, "Int8")

    # Compare all models
    compare_models()

    print(f"\n✅ Quantization completed!")
    print(f"📁 Float16 model: {float16_size:.1f} MB - This is your best bet!")
    if int8_size > 0:
        print(f"📁 Int8 model: {int8_size:.1f} MB")

    print(f"\n💡 RECOMMENDATION:")
    print(f"Use the float16 model - it's half the precision of float32,")
    print(f"runs efficiently on Apple's Neural Engine, and is the most")
    print(f"reliable form of quantization in CoreML.")

if __name__ == "__main__":
    main()