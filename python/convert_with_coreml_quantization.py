#!/usr/bin/env python3
"""
Convert to CoreML with Built-in Quantization

Instead of using our PyTorch quantized model, let's use CoreML's
built-in quantization during the conversion process.

Usage:
    python convert_with_coreml_quantization.py
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

def create_quantized_coreml_encoder():
    """Create quantized CoreML encoder using CoreML's built-in quantization"""
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

    # Convert to CoreML with quantization
    print("🔄 Converting to CoreML with int8 quantization...")
    start_time = time.time()

    # Use CoreML's built-in quantization
    coreml_model = ct.convert(
        traced_encoder,
        inputs=[ct.TensorType(name="mel", shape=sample_mel.shape)],
        outputs=[ct.TensorType(name="encoder_output")],
        compute_units=ct.ComputeUnit.CPU_AND_NE,  # CPU and Neural Engine

        # Enable quantization during conversion
        compute_precision=ct.precision.FLOAT16,  # Use float16 for intermediate computations

        # Additional optimization
        minimum_deployment_target=ct.target.iOS16  # Target iOS 16+
    )

    conversion_time = time.time() - start_time
    print(f"✅ CoreML conversion completed in {conversion_time:.1f}s")

    # Apply post-training quantization
    print("🔄 Applying int8 quantization...")
    quantized_model = ct.models.neural_network.quantization_utils.quantize_weights(
        coreml_model,
        nbits=8,
        quantization_mode="linear"
    )

    # Save the quantized model
    output_path = "whisper_encoder_coreml_quantized.mlpackage"
    print(f"💾 Saving quantized CoreML model to {output_path}...")
    quantized_model.save(output_path)

    # Get file size
    if Path(output_path).is_dir():
        size = sum(f.stat().st_size for f in Path(output_path).rglob('*') if f.is_file())
    else:
        size = Path(output_path).stat().st_size
    size_mb = size / (1024 * 1024)

    print(f"📁 Quantized model saved: {size_mb:.1f} MB")
    memory_end = get_memory_mb()
    print(f"💾 Memory used: {memory_end - memory_start:.1f} MB")

    return output_path, size_mb

def test_quantized_model(model_path):
    """Test the quantized CoreML model"""
    print(f"\\n🧪 Testing quantized model: {model_path}")

    if not Path(model_path).exists():
        print(f"❌ Model not found: {model_path}")
        return

    # Load the model
    print("🔄 Loading quantized CoreML model...")
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

    print(f"✅ Inference completed in {inference_time:.3f}s")
    print(f"📤 Output shape: {output_shape}")

def compare_with_original():
    """Compare with original CoreML model if available"""
    print("\\n📊 COMPARISON WITH ORIGINAL")
    print("=" * 40)

    original_path = "../EnglishSubtitles/Models/openai_whisper-medium/AudioEncoder.mlmodelc"
    if Path(original_path).exists():
        # Get original size
        if Path(original_path).is_dir():
            orig_size = sum(f.stat().st_size for f in Path(original_path).rglob('*') if f.is_file())
        else:
            orig_size = Path(original_path).stat().st_size
        orig_size_mb = orig_size / (1024 * 1024)

        # Get our quantized size
        quant_path = "whisper_encoder_coreml_quantized.mlpackage"
        if Path(quant_path).exists():
            if Path(quant_path).is_dir():
                quant_size = sum(f.stat().st_size for f in Path(quant_path).rglob('*') if f.is_file())
            else:
                quant_size = Path(quant_path).stat().st_size
            quant_size_mb = quant_size / (1024 * 1024)

            print(f"Original AudioEncoder: {orig_size_mb:.1f} MB")
            print(f"Quantized CoreML:      {quant_size_mb:.1f} MB")

            if quant_size_mb < orig_size_mb:
                compression_ratio = orig_size_mb / quant_size_mb
                savings = orig_size_mb - quant_size_mb
                print(f"✅ Compression: {compression_ratio:.1f}x smaller")
                print(f"💾 Space saved: {savings:.1f} MB")
            else:
                print("⚠️ No size reduction achieved")
        else:
            print("❌ Quantized model not found for comparison")
    else:
        print("❌ Original model not found for comparison")

def main():
    """Main conversion workflow"""
    print("🚀 Converting to CoreML with Built-in Quantization")
    print("=" * 50)

    # Create quantized CoreML model
    model_path, size_mb = create_quantized_coreml_encoder()

    # Test the model
    test_quantized_model(model_path)

    # Compare with original
    compare_with_original()

    print(f"\\n✅ CoreML quantization completed!")
    print(f"📁 Model saved: {model_path} ({size_mb:.1f} MB)")

if __name__ == "__main__":
    main()