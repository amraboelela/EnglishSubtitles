#!/usr/bin/env python3
"""
Quantize Complete Whisper Model - Encoder + Decoder

Quantizes both AudioEncoder and TextDecoder, then compiles them to mlmodelc format.

Usage:
    python quantize_complete_whisper.py
"""

import torch
import whisper
import numpy as np
import coremltools as ct
from pathlib import Path
import time
import subprocess
import os

def get_model_size_mb(path):
    """Get model size in MB"""
    if Path(path).is_dir():
        size = sum(f.stat().st_size for f in Path(path).rglob('*') if f.is_file())
    else:
        size = Path(path).stat().st_size
    return size / (1024 * 1024)

def quantize_encoder():
    """Quantize the AudioEncoder"""
    print("🔄 Quantizing AudioEncoder...")

    # Load model
    model = whisper.load_model("medium")
    encoder = model.encoder
    encoder.eval()

    # Create sample input
    sample_mel = torch.randn(1, 80, 3000)

    # Trace the encoder
    traced_encoder = torch.jit.trace(encoder, sample_mel)

    # Convert to CoreML with float32 first
    print("🔄 Converting AudioEncoder to CoreML...")
    base_model = ct.convert(
        traced_encoder,
        inputs=[ct.TensorType(name="mel", shape=sample_mel.shape)],
        outputs=[ct.TensorType(name="encoder_output")],
        compute_units=ct.ComputeUnit.CPU_AND_NE,
        compute_precision=ct.precision.FLOAT32,
        minimum_deployment_target=ct.target.iOS16
    )

    # Apply int8 quantization
    print("🔄 Applying int8 quantization to AudioEncoder...")
    from coremltools.optimize.coreml import OpLinearQuantizerConfig, OptimizationConfig

    op_config = OpLinearQuantizerConfig(
        mode="linear_symmetric",
        weight_threshold=512
    )
    config = OptimizationConfig(global_config=op_config)

    quantized_encoder = ct.optimize.coreml.linear_quantize_weights(
        base_model,
        config=config
    )

    # Save quantized encoder
    encoder_path = "AudioEncoder_quantized.mlpackage"
    quantized_encoder.save(encoder_path)
    encoder_size = get_model_size_mb(encoder_path)
    print(f"✅ Quantized AudioEncoder: {encoder_size:.1f} MB")

    return encoder_path, encoder_size

def quantize_decoder():
    """Quantize the TextDecoder"""
    print("\n🔄 Quantizing TextDecoder...")

    # Load model
    model = whisper.load_model("medium")
    decoder = model.decoder
    decoder.eval()

    # Create sample inputs for decoder
    # The decoder takes multiple inputs: tokens, audio_features, kv_cache
    batch_size = 1
    seq_len = 224  # Max sequence length
    n_audio_ctx = 1500  # Audio context length
    n_text_state = 1024  # Text embedding dimension

    # Sample inputs for decoder
    tokens = torch.randint(0, 51865, (batch_size, seq_len))  # Token IDs
    audio_features = torch.randn(batch_size, n_audio_ctx, n_text_state)  # From encoder

    print("🔄 Tracing TextDecoder...")
    try:
        # Try to trace the decoder - this might be complex
        traced_decoder = torch.jit.trace(decoder, (tokens, audio_features))

        print("🔄 Converting TextDecoder to CoreML...")
        # Convert to CoreML
        base_decoder = ct.convert(
            traced_decoder,
            inputs=[
                ct.TensorType(name="tokens", shape=tokens.shape),
                ct.TensorType(name="audio_features", shape=audio_features.shape)
            ],
            outputs=[ct.TensorType(name="logits")],
            compute_units=ct.ComputeUnit.CPU_AND_NE,
            compute_precision=ct.precision.FLOAT32,
            minimum_deployment_target=ct.target.iOS16
        )

        # Apply int8 quantization
        print("🔄 Applying int8 quantization to TextDecoder...")
        from coremltools.optimize.coreml import OpLinearQuantizerConfig, OptimizationConfig

        op_config = OpLinearQuantizerConfig(
            mode="linear_symmetric",
            weight_threshold=512
        )
        config = OptimizationConfig(global_config=op_config)

        quantized_decoder = ct.optimize.coreml.linear_quantize_weights(
            base_decoder,
            config=config
        )

        # Save quantized decoder
        decoder_path = "TextDecoder_quantized.mlpackage"
        quantized_decoder.save(decoder_path)
        decoder_size = get_model_size_mb(decoder_path)
        print(f"✅ Quantized TextDecoder: {decoder_size:.1f} MB")

        return decoder_path, decoder_size

    except Exception as e:
        print(f"❌ TextDecoder quantization failed: {e}")
        print("💡 The decoder is very complex - let's try a different approach")
        return None, 0

def compile_to_mlmodelc(mlpackage_path, output_name):
    """Compile .mlpackage to .mlmodelc format"""
    if not Path(mlpackage_path).exists():
        print(f"❌ {mlpackage_path} not found")
        return None, 0

    print(f"🔄 Compiling {mlpackage_path} to .mlmodelc format...")

    # Create output directory
    mlmodelc_path = f"{output_name}.mlmodelc"

    try:
        # Use xcrun to compile the model
        cmd = [
            "xcrun", "coremlcompiler", "compile",
            mlpackage_path,
            "."
        ]

        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        print(f"✅ Compiled to {mlmodelc_path}")

        # Check if compilation was successful
        if Path(mlmodelc_path).exists():
            size_mb = get_model_size_mb(mlmodelc_path)
            print(f"📁 Compiled size: {size_mb:.1f} MB")
            return mlmodelc_path, size_mb
        else:
            print(f"❌ Compilation failed - output not found")
            return None, 0

    except subprocess.CalledProcessError as e:
        print(f"❌ Compilation failed: {e}")
        print(f"stderr: {e.stderr}")
        return None, 0
    except Exception as e:
        print(f"❌ Compilation error: {e}")
        return None, 0

def copy_other_models():
    """Copy MelSpectrogram and other models that don't need quantization"""
    print("\n🔄 Copying MelSpectrogram and other models...")

    source_dir = "/Users/amraboelela/develop/swift/EnglishSubtitles/EnglishSubtitles/Models/openai_whisper-medium"

    models_to_copy = [
        "MelSpectrogram.mlmodelc",
        "config.json",
        "generation_config.json",
        "tokenizer.json",
        "tokenizer_config.json"
    ]

    copied_files = []
    for model_file in models_to_copy:
        source_path = Path(source_dir) / model_file
        dest_path = Path(".") / model_file

        if source_path.exists():
            if source_path.is_dir():
                # Copy directory
                import shutil
                if dest_path.exists():
                    shutil.rmtree(dest_path)
                shutil.copytree(source_path, dest_path)
            else:
                # Copy file
                import shutil
                shutil.copy2(source_path, dest_path)

            size_mb = get_model_size_mb(dest_path)
            print(f"✅ Copied {model_file}: {size_mb:.1f} MB")
            copied_files.append((str(dest_path), size_mb))
        else:
            print(f"⚠️ {model_file} not found in source")

    return copied_files

def compare_sizes():
    """Compare original vs quantized model sizes"""
    print("\n📊 SIZE COMPARISON")
    print("=" * 50)

    # Original models
    original_dir = "/Users/amraboelela/develop/swift/EnglishSubtitles/EnglishSubtitles/Models/openai_whisper-medium"
    original_models = [
        ("AudioEncoder.mlmodelc", "Original AudioEncoder"),
        ("TextDecoder.mlmodelc", "Original TextDecoder"),
        ("MelSpectrogram.mlmodelc", "MelSpectrogram"),
    ]

    original_total = 0
    print("ORIGINAL MODELS:")
    for model_file, description in original_models:
        model_path = Path(original_dir) / model_file
        if model_path.exists():
            size_mb = get_model_size_mb(model_path)
            print(f"  {description:20}: {size_mb:6.1f} MB")
            original_total += size_mb
        else:
            print(f"  {description:20}: Not found")

    print(f"  {'TOTAL ORIGINAL':20}: {original_total:6.1f} MB")

    # Quantized models
    quantized_models = [
        ("AudioEncoder.mlmodelc", "Quantized AudioEncoder"),
        ("TextDecoder.mlmodelc", "Quantized TextDecoder"),
        ("MelSpectrogram.mlmodelc", "MelSpectrogram (same)"),
    ]

    quantized_total = 0
    print("\nQUANTIZED MODELS:")
    for model_file, description in quantized_models:
        if Path(model_file).exists():
            size_mb = get_model_size_mb(model_file)
            print(f"  {description:20}: {size_mb:6.1f} MB")
            quantized_total += size_mb
        else:
            print(f"  {description:20}: Not created")

    print(f"  {'TOTAL QUANTIZED':20}: {quantized_total:6.1f} MB")

    if quantized_total > 0 and original_total > 0:
        compression_ratio = original_total / quantized_total
        savings_mb = original_total - quantized_total
        savings_percent = (savings_mb / original_total) * 100

        print(f"\n🏆 COMPRESSION RESULTS:")
        print(f"   Compression ratio: {compression_ratio:.1f}x smaller")
        print(f"   Space saved: {savings_mb:.1f} MB ({savings_percent:.1f}%)")

def main():
    """Main quantization workflow"""
    print("🚀 Complete Whisper Model Quantization")
    print("=" * 50)

    # Step 1: Quantize AudioEncoder
    encoder_package, encoder_size = quantize_encoder()

    # Step 2: Try to quantize TextDecoder
    decoder_package, decoder_size = quantize_decoder()

    # Step 3: Compile to .mlmodelc format
    print("\n🔄 COMPILING TO .mlmodelc FORMAT")
    print("=" * 40)

    compiled_models = []

    # Compile AudioEncoder
    if encoder_package:
        compiled_encoder, compiled_encoder_size = compile_to_mlmodelc(encoder_package, "AudioEncoder")
        if compiled_encoder:
            compiled_models.append(("AudioEncoder", compiled_encoder_size))

    # Compile TextDecoder if quantization worked
    if decoder_package:
        compiled_decoder, compiled_decoder_size = compile_to_mlmodelc(decoder_package, "TextDecoder")
        if compiled_decoder:
            compiled_models.append(("TextDecoder", compiled_decoder_size))

    # Step 4: Copy other models
    copied_models = copy_other_models()

    # Step 5: Compare sizes
    compare_sizes()

    # Summary
    print(f"\n✅ QUANTIZATION COMPLETED!")
    if compiled_models:
        print(f"📁 Compiled quantized models: {len(compiled_models)}")
        for model_name, size_mb in compiled_models:
            print(f"   {model_name}: {size_mb:.1f} MB")

    print(f"\n💡 NEXT STEPS:")
    print(f"   1. Test the quantized models with your app")
    print(f"   2. If they work, replace the models in your app bundle")
    print(f"   3. Enjoy the smaller app size and potentially faster performance!")

if __name__ == "__main__":
    main()