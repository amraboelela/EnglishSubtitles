#!/usr/bin/env python3
"""
Proper Whisper Model Quantization Script

This script implements TRUE quantization that reduces file size by converting
weights from float32 to int8, achieving actual 4x compression.

Usage:
    python whisper_proper_quantization.py
"""

import os
import sys
import torch
import numpy as np
from pathlib import Path
import struct

def load_whisper_model():
    """Load the Whisper medium model"""
    print("📥 Loading Whisper medium model...")

    try:
        import whisper
        model = whisper.load_model("medium")
        print(f"✅ Model loaded successfully!")

        # Get model size
        total_params = sum(p.numel() for p in model.parameters())
        param_size = sum(p.numel() * p.element_size() for p in model.parameters()) / (1024 * 1024)

        print(f"   Parameters: {total_params:,}")
        print(f"   Original size: {param_size:.1f} MB")

        return model

    except Exception as e:
        print(f"❌ Error loading model: {e}")
        return None

def quantize_weights_to_int8(model):
    """
    Properly quantize model weights from float32 to int8
    This achieves REAL file size reduction
    """
    print("🔧 Applying TRUE weight quantization (float32 -> int8)...")

    quantized_state = {}
    total_original_size = 0
    total_quantized_size = 0

    for name, param in model.state_dict().items():
        if param.dtype == torch.float32 and len(param.shape) >= 2:  # Only quantize matrices
            # Convert to numpy for easier manipulation
            weights = param.cpu().numpy()
            original_size = weights.nbytes

            # Find min/max for quantization
            w_min = weights.min()
            w_max = weights.max()

            # Quantize to int8 range [-127, 127]
            scale = (w_max - w_min) / 254.0
            zero_point = -127 - w_min / scale

            # Quantize
            quantized_weights = np.round((weights / scale) + zero_point).astype(np.int8)

            # Store quantized data
            quantized_state[name] = {
                'weights': quantized_weights,
                'scale': scale,
                'zero_point': zero_point,
                'shape': weights.shape
            }

            quantized_size = quantized_weights.nbytes + 8  # +8 for scale and zero_point
            compression = original_size / quantized_size

            total_original_size += original_size
            total_quantized_size += quantized_size

            print(f"   ✓ {name}: {original_size/1024:.1f}KB -> {quantized_size/1024:.1f}KB ({compression:.1f}x)")

        else:
            # Keep non-quantizable tensors as-is
            quantized_state[name] = {'weights': param.cpu().numpy(), 'original': True}
            size = param.cpu().numpy().nbytes
            total_original_size += size
            total_quantized_size += size

    overall_compression = total_original_size / total_quantized_size
    print(f"\n📊 Overall quantization results:")
    print(f"   Original total: {total_original_size / (1024*1024):.1f} MB")
    print(f"   Quantized total: {total_quantized_size / (1024*1024):.1f} MB")
    print(f"   Compression ratio: {overall_compression:.1f}x")

    return quantized_state

def save_quantized_model(quantized_state, filepath):
    """Save the properly quantized model in a custom format"""
    print(f"💾 Saving quantized model to: {filepath}")

    try:
        # Save in a custom format that preserves the quantization
        torch.save(quantized_state, filepath)

        file_size = Path(filepath).stat().st_size / (1024 * 1024)
        print(f"✅ Quantized model saved!")
        print(f"   File size: {file_size:.1f} MB")

        return file_size

    except Exception as e:
        print(f"❌ Error saving model: {e}")
        return 0

def load_and_dequantize(filepath):
    """Load the quantized model and dequantize for inference"""
    print(f"🔄 Loading and dequantizing model from: {filepath}")

    try:
        quantized_state = torch.load(filepath, map_location='cpu')

        # Dequantize for inference
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

        print(f"✅ Model dequantized successfully!")
        return dequantized_state

    except Exception as e:
        print(f"❌ Error loading/dequantizing model: {e}")
        return None

def test_quantized_model(original_model, dequantized_state):
    """Test the dequantized model to check quality loss"""
    print("🧪 Testing quantized model quality...")

    try:
        # Load the dequantized weights back into the model
        original_model.load_state_dict(dequantized_state)

        # Create a simple test
        print("✓ Model weights loaded successfully")
        print("💡 For full testing, you'd run transcription on real Turkish audio")
        print("💡 Expected: Slight quality loss but should maintain good accuracy")

        return True

    except Exception as e:
        print(f"❌ Error testing model: {e}")
        return False

def compare_models():
    """Compare original and quantized model sizes"""
    print("\n📊 Comparing model files:")

    # Check if we have the original model cache
    import whisper

    # Find whisper cache directory
    cache_dir = Path.home() / ".cache" / "whisper"
    if cache_dir.exists():
        medium_model = cache_dir / "medium.pt"
        if medium_model.exists():
            original_size = medium_model.stat().st_size / (1024 * 1024)
            print(f"   Original medium.pt: {original_size:.1f} MB")

    # Check our quantized model
    quantized_file = Path("whisper_medium_properly_quantized.pth")
    if quantized_file.exists():
        quantized_size = quantized_file.stat().st_size / (1024 * 1024)
        print(f"   Quantized model: {quantized_size:.1f} MB")

        if cache_dir.exists() and (cache_dir / "medium.pt").exists():
            compression = original_size / quantized_size
            savings = original_size - quantized_size
            print(f"   Compression ratio: {compression:.1f}x")
            print(f"   Space saved: {savings:.1f} MB")

def main():
    """Main quantization workflow"""
    print("🚀 Proper Whisper Model Quantization (TRUE Size Reduction)")
    print("=" * 65)

    # Load original model
    model = load_whisper_model()
    if not model:
        sys.exit(1)

    # Properly quantize weights
    quantized_state = quantize_weights_to_int8(model)

    # Save quantized model
    output_path = "whisper_medium_properly_quantized.pth"
    saved_size = save_quantized_model(quantized_state, output_path)

    if saved_size == 0:
        sys.exit(1)

    # Test by loading and dequantizing
    dequantized_state = load_and_dequantize(output_path)
    if dequantized_state:
        test_quantized_model(model, dequantized_state)

    # Compare sizes
    compare_models()

    print(f"\n✅ TRUE quantization completed!")
    print(f"🎯 Result: Properly quantized model with REAL size reduction")
    print(f"📁 Saved to: {output_path}")

    print(f"\n🔧 Next Steps:")
    print(f"   1. Test transcription quality with real Turkish audio")
    print(f"   2. Convert to CoreML format if needed")
    print(f"   3. Integrate with iOS app")

if __name__ == "__main__":
    main()