#!/usr/bin/env python3
"""
WhisperKit CoreML Model Quantization Script

This script quantizes the WhisperKit medium CoreML model to reduce memory usage
and improve performance on iOS devices, while maintaining Turkish transcription quality.

Requirements:
- pip install coremltools

Usage:
    python quantize_whisper_model.py
"""

import os
import sys
import shutil
from pathlib import Path
import coremltools as ct

def get_model_size_mb(path):
    """Get model size in MB"""
    if path.is_file():
        return path.stat().st_size / (1024 * 1024)
    elif path.is_dir():
        # For .mlmodelc directories, sum all files
        total_size = sum(f.stat().st_size for f in path.rglob('*') if f.is_file())
        return total_size / (1024 * 1024)
    return 0

def quantize_compiled_model(model_path, output_path, nbits=8):
    """
    Quantize a compiled CoreML model (.mlmodelc) by loading and re-quantizing

    Args:
        model_path: Path to the original compiled CoreML model (.mlmodelc)
        output_path: Path for the quantized model
        nbits: Number of bits for quantization (8 or 16)
    """
    print(f"🔄 Quantizing compiled model {model_path.name} to {nbits}-bit...")

    try:
        # Method 1: Try loading compiled model directly
        try:
            model = ct.models.MLModel(str(model_path))
            print(f"✓ Loaded compiled model: {model_path.name}")
        except Exception as load_error:
            print(f"⚠️  Could not load compiled model directly: {load_error}")

            # Method 2: Try to load from .mil file
            mil_file = model_path / "model.mil"
            if mil_file.exists():
                print(f"🔄 Attempting to load from MIL file: {mil_file}")
                try:
                    # This is more complex - we'd need to use MIL tools
                    # For now, let's try a workaround
                    raise Exception("MIL loading not implemented yet")
                except Exception as mil_error:
                    print(f"❌ MIL loading failed: {mil_error}")
                    return False, 0, 0
            else:
                print(f"❌ No model.mil file found in {model_path}")
                return False, 0, 0

        # Apply quantization
        print(f"🔧 Applying {nbits}-bit quantization...")
        quantized_model = ct.models.neural_network.quantization_utils.quantize_weights(
            model,
            nbits=nbits,
            quantization_mode="linear"
        )

        # Save quantized model
        print(f"💾 Saving quantized model to {output_path}")
        quantized_model.save(str(output_path))

        # Get file sizes for comparison
        original_size = get_model_size_mb(model_path)
        quantized_size = get_model_size_mb(output_path)
        compression_ratio = original_size / quantized_size if quantized_size > 0 else 0

        print(f"✅ Quantized {model_path.name}:")
        print(f"   Original size: {original_size:.1f} MB")
        print(f"   Quantized size: {quantized_size:.1f} MB")
        print(f"   Compression ratio: {compression_ratio:.1f}x")
        print(f"   Saved to: {output_path}")

        return True, original_size, quantized_size

    except Exception as e:
        print(f"❌ Error quantizing {model_path.name}: {str(e)}")
        print(f"💡 This might be because the model is already compiled.")
        return False, 0, 0

def download_and_quantize_original():
    """
    Alternative approach: Download original uncompiled WhisperKit models and quantize them
    """
    print("\n🔄 Alternative: Downloading original uncompiled models...")

    try:
        from huggingface_hub import snapshot_download

        # Download the original WhisperKit models from HuggingFace
        print("📥 Downloading from HuggingFace...")
        model_path = snapshot_download(
            repo_id="argmaxinc/whisperkit-coreml",
            allow_patterns="openai_whisper-medium/*.mlmodel",
            local_dir="./original_models",
            local_dir_use_symlinks=False
        )

        original_dir = Path(model_path) / "openai_whisper-medium"
        if original_dir.exists():
            print(f"✅ Downloaded to: {original_dir}")
            return original_dir
        else:
            print("❌ Download failed - directory not found")
            return None

    except ImportError:
        print("❌ huggingface_hub not installed. Install with: pip install huggingface_hub")
        return None
    except Exception as e:
        print(f"❌ Download failed: {e}")
        return None

def copy_files(src_dir, dest_dir, exclude_patterns=None):
    """Copy files from src to dest, excluding certain patterns"""
    if exclude_patterns is None:
        exclude_patterns = []

    dest_dir.mkdir(parents=True, exist_ok=True)

    for item in src_dir.iterdir():
        # Skip if matches exclude pattern
        if any(pattern in item.name for pattern in exclude_patterns):
            continue

        dest_path = dest_dir / item.name
        if item.is_file():
            shutil.copy2(item, dest_path)
            print(f"✓ Copied {item.name}")
        elif item.is_dir() and not item.name.endswith('.mlmodelc'):
            shutil.copytree(item, dest_path, dirs_exist_ok=True)
            print(f"✓ Copied directory {item.name}")

def main():
    """Main quantization process"""
    print("🚀 WhisperKit CoreML Model Quantization")
    print("=" * 50)

    # Check if coremltools is installed
    try:
        import coremltools as ct
        print(f"✓ CoreML Tools version: {ct.__version__}")
    except ImportError:
        print("❌ coremltools not found. Please install it:")
        print("   pip install coremltools")
        sys.exit(1)

    # Define paths
    model_dir = Path("./EnglishSubtitles/Models/openai_whisper-medium")
    output_dir = Path("./EnglishSubtitles/Models/openai_whisper-medium-int8")

    if not model_dir.exists():
        print(f"❌ Model directory not found: {model_dir}")
        sys.exit(1)

    # Find CoreML model files to quantize
    models_to_quantize = [
        "AudioEncoder.mlmodelc",
        "TextDecoder.mlmodelc"
        # Skip MelSpectrogram.mlmodelc as it's only 372KB
    ]

    model_files = []
    for model_name in models_to_quantize:
        model_path = model_dir / model_name
        if model_path.exists():
            model_files.append(model_path)
        else:
            print(f"⚠️  Model not found: {model_name}")

    if not model_files:
        print("❌ No CoreML model files found to quantize")
        sys.exit(1)

    print(f"📁 Found {len(model_files)} models to quantize:")
    for f in model_files:
        size = get_model_size_mb(f)
        print(f"   - {f.name}: {size:.1f} MB")

    # Create output directory
    print(f"\n🎯 Creating quantized models in: {output_dir}")
    output_dir.mkdir(parents=True, exist_ok=True)

    # Copy all non-model files first
    print("\n📋 Copying configuration files...")
    copy_files(model_dir, output_dir, exclude_patterns=['.mlmodelc'])

    # Copy MelSpectrogram.mlmodelc without quantization (too small to benefit)
    mel_spec_path = model_dir / "MelSpectrogram.mlmodelc"
    if mel_spec_path.exists():
        mel_spec_dest = output_dir / "MelSpectrogram.mlmodelc"
        shutil.copytree(mel_spec_path, mel_spec_dest, dirs_exist_ok=True)
        print(f"✓ Copied MelSpectrogram.mlmodelc (no quantization needed)")

    # Quantize each large model file
    print(f"\n🔧 Quantizing compiled models...")
    success_count = 0
    total_original_size = 0
    total_quantized_size = 0

    # First try to quantize the compiled models directly
    for model_file in model_files:
        output_file = output_dir / model_file.name

        success, orig_size, quant_size = quantize_compiled_model(model_file, output_file, nbits=8)
        if success:
            success_count += 1
            total_original_size += orig_size
            total_quantized_size += quant_size

    # If compiled model quantization failed, try downloading originals
    if success_count == 0:
        print(f"\n🔄 Compiled model quantization failed. Trying alternative approach...")

        # Try to download and quantize original models
        original_model_dir = download_and_quantize_original()
        if original_model_dir:
            print(f"🔧 Quantizing original uncompiled models...")

            # Look for .mlmodel files
            original_models = list(original_model_dir.glob("*.mlmodel"))
            if original_models:
                for original_model in original_models:
                    if any(name in original_model.name for name in ["AudioEncoder", "TextDecoder"]):
                        output_file = output_dir / original_model.name.replace(".mlmodel", ".mlmodelc")

                        # Load and quantize original model
                        try:
                            model = ct.models.MLModel(str(original_model))
                            quantized_model = ct.models.neural_network.quantization_utils.quantize_weights(
                                model, nbits=8, quantization_mode="linear"
                            )
                            quantized_model.save(str(output_file))

                            orig_size = get_model_size_mb(original_model)
                            quant_size = get_model_size_mb(output_file)

                            print(f"✅ Quantized {original_model.name} -> {output_file.name}")
                            print(f"   Original: {orig_size:.1f} MB -> Quantized: {quant_size:.1f} MB")

                            success_count += 1
                            total_original_size += orig_size
                            total_quantized_size += quant_size

                        except Exception as e:
                            print(f"❌ Failed to quantize {original_model.name}: {e}")
            else:
                print("❌ No .mlmodel files found in downloaded models")

    # Add MelSpectrogram size to totals
    mel_size = get_model_size_mb(mel_spec_path) if mel_spec_path.exists() else 0
    total_original_size += mel_size
    total_quantized_size += mel_size

    # Summary
    print(f"\n📊 Quantization Summary:")
    print(f"   Successfully quantized: {success_count}/{len(model_files)} models")
    print(f"   Total original size: {total_original_size:.1f} MB")
    print(f"   Total quantized size: {total_quantized_size:.1f} MB")
    if total_quantized_size > 0:
        total_compression = total_original_size / total_quantized_size
        savings_mb = total_original_size - total_quantized_size
        print(f"   Total compression: {total_compression:.1f}x")
        print(f"   Space saved: {savings_mb:.1f} MB")
    print(f"   Output directory: {output_dir}")

    if success_count == len(model_files):
        print("\n✅ Quantization completed successfully!")
        print("\n🔧 Next Steps:")
        print("1. Update WhisperKitManager to use 'openai_whisper-medium-int8'")
        print("2. Test the app to verify performance improvements")
        print("3. Check that Turkish transcription quality is maintained")
    else:
        print(f"\n⚠️  {len(model_files) - success_count} models failed to quantize")

if __name__ == "__main__":
    main()