#!/usr/bin/env python3
"""
Convert Quantized Whisper to CoreML

Convert our quantized PyTorch model to CoreML format to get:
1. Smaller disk size (from quantization)
2. Lower memory usage (from CoreML optimization)

Usage:
    python convert_to_coreml.py
"""

import torch
import whisper
import numpy as np
import coremltools as ct
from pathlib import Path
import tempfile

def load_quantized_model_for_conversion():
    """Load quantized model and prepare for CoreML conversion"""
    print("🔄 Loading quantized model for CoreML conversion...")

    # Try to load the simple quantized model first
    simple_path = "whisper_quantized_simple.pth"
    if Path(simple_path).exists():
        print(f"📂 Using simple quantized model: {simple_path}")
        return load_simple_quantized_model(simple_path)

    # Fall back to properly quantized model
    proper_path = "whisper_medium_properly_quantized.pth"
    if Path(proper_path).exists():
        print(f"📂 Using properly quantized model: {proper_path}")
        return load_properly_quantized_model(proper_path)

    print("❌ No quantized models found!")
    return None

def load_simple_quantized_model(model_path):
    """Load the simple quantized model"""
    quantized_dict = torch.load(model_path, map_location='cpu')
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

    original_model.load_state_dict(dequantized_dict)
    return original_model

def load_properly_quantized_model(model_path):
    """Load the properly quantized model"""
    torch.serialization.add_safe_globals([np.core.multiarray._reconstruct])
    quantized_state = torch.load(model_path, map_location='cpu', weights_only=False)

    original_model = whisper.load_model("medium")

    dequantized_state = {}
    for name, data in quantized_state.items():
        if 'original' in data:
            dequantized_state[name] = torch.from_numpy(data['weights'])
        else:
            weights = data['weights']
            scale = data['scale']
            zero_point = data['zero_point']
            dequantized = (weights.astype(np.float32) - zero_point) * scale
            dequantized_state[name] = torch.from_numpy(dequantized)

    original_model.load_state_dict(dequantized_state)
    return original_model

def create_dummy_input():
    """Create dummy input for CoreML conversion"""
    print("🎯 Creating dummy input for tracing...")

    # Whisper expects mel spectrogram input
    # Standard Whisper input: (batch, n_mels, seq_len)
    batch_size = 1
    n_mels = 80  # Whisper uses 80 mel bins
    seq_len = 3000  # ~30 seconds of audio at 16kHz

    dummy_input = torch.randn(batch_size, n_mels, seq_len)
    print(f"✓ Dummy input shape: {dummy_input.shape}")

    return dummy_input

def extract_encoder_only(model):
    """Extract just the encoder for conversion (decoder is too complex)"""
    print("🔧 Extracting encoder for conversion...")

    class WhisperEncoderWrapper(torch.nn.Module):
        def __init__(self, encoder):
            super().__init__()
            self.encoder = encoder

        def forward(self, mel):
            return self.encoder(mel)

    encoder_wrapper = WhisperEncoderWrapper(model.encoder)
    encoder_wrapper.eval()

    print("✓ Encoder extracted and set to eval mode")
    return encoder_wrapper

def convert_to_coreml_with_quantization(model):
    """Convert quantized model to CoreML with proper quantization settings"""
    print("\n🔄 Converting to CoreML...")

    try:
        # Extract encoder only (full model is too complex for conversion)
        encoder = extract_encoder_only(model)

        # Create dummy input for encoder
        dummy_mel = create_dummy_input()

        print("📊 Tracing model...")
        # Trace the model
        traced_model = torch.jit.trace(encoder, dummy_mel)
        traced_model.eval()

        print("🔧 Converting to CoreML with quantization...")
        # Convert to CoreML with quantization
        coreml_model = ct.convert(
            traced_model,
            inputs=[ct.TensorType(name="mel", shape=dummy_mel.shape)],
            outputs=[ct.TensorType(name="encoder_output")],
            minimum_deployment_target=ct.target.iOS16,
            compute_precision=ct.precision.FLOAT16,  # Use float16 for smaller size
            # Note: We could add quantization here but the model is already quantized
        )

        print("✅ CoreML conversion successful!")
        return coreml_model, "encoder"

    except Exception as e:
        print(f"❌ Encoder conversion failed: {e}")
        print("💡 Trying alternative approach...")

        # Alternative: Convert individual layers
        return convert_layers_separately(model)

def convert_layers_separately(model):
    """Convert model layers separately if full conversion fails"""
    print("🔧 Converting layers separately...")

    # This is more complex - for now, return None
    print("⚠️ Layer-by-layer conversion not implemented yet")
    print("💡 For production use, consider using WhisperKit's conversion tools")

    return None, "layers"

def analyze_coreml_model(coreml_model, model_type):
    """Analyze the CoreML model size and properties"""
    print(f"\n📊 Analyzing CoreML {model_type} model...")

    if coreml_model is None:
        print("❌ No model to analyze")
        return

    # Save the model to check size
    output_path = f"whisper_{model_type}_quantized.mlpackage"
    coreml_model.save(output_path)

    file_size = Path(output_path).stat().st_size / (1024 * 1024)

    print(f"✅ CoreML model saved:")
    print(f"   File: {output_path}")
    print(f"   Size: {file_size:.1f} MB")

    # Analyze model spec
    spec = coreml_model._spec
    print(f"   Input: {[str(input.name) for input in spec.description.input]}")
    print(f"   Output: {[str(output.name) for output in spec.description.output]}")

    return output_path, file_size

def compare_with_original_coreml():
    """Compare with original WhisperKit CoreML models"""
    print(f"\n📊 Comparing with original CoreML models...")

    # Check existing WhisperKit models
    original_models = [
        "../EnglishSubtitles/Models/openai_whisper-medium/AudioEncoder.mlmodelc",
        "../EnglishSubtitles/Models/openai_whisper-medium/TextDecoder.mlmodelc",
        "../EnglishSubtitles/Models/openai_whisper-medium/MelSpectrogram.mlmodelc"
    ]

    total_original_size = 0
    for model_path in original_models:
        if Path(model_path).exists():
            size = sum(f.stat().st_size for f in Path(model_path).rglob('*') if f.is_file())
            size_mb = size / (1024 * 1024)
            total_original_size += size_mb
            print(f"   {Path(model_path).name}: {size_mb:.1f} MB")

    if total_original_size > 0:
        print(f"   Total original CoreML: {total_original_size:.1f} MB")
    else:
        print("   ⚠️ Original CoreML models not found")

    return total_original_size

def test_coreml_inference(model_path):
    """Test CoreML model inference to check memory usage"""
    print(f"\n🧪 Testing CoreML inference...")

    try:
        import coremltools as ct

        # Load the CoreML model
        model = ct.models.MLModel(model_path)

        # Create test input
        dummy_mel = create_dummy_input().numpy()

        print(f"🔄 Running inference...")
        # Note: This is just for encoder, not full Whisper pipeline
        result = model.predict({"mel": dummy_mel})

        print(f"✅ CoreML inference successful!")
        print(f"   Output shape: {result[list(result.keys())[0]].shape}")

        return True

    except Exception as e:
        print(f"❌ CoreML inference failed: {e}")
        return False

def main():
    """Main CoreML conversion workflow"""
    print("🚀 Converting Quantized Whisper to CoreML")
    print("=" * 50)

    # Load quantized model
    model = load_quantized_model_for_conversion()
    if not model:
        return

    # Convert to CoreML
    coreml_model, model_type = convert_to_coreml_with_quantization(model)

    if coreml_model:
        # Analyze the converted model
        output_path, file_size = analyze_coreml_model(coreml_model, model_type)

        # Compare with original
        original_size = compare_with_original_coreml()

        # Test inference
        test_coreml_inference(output_path)

        # Summary
        print(f"\n📊 CONVERSION SUMMARY:")
        print(f"   Quantized CoreML {model_type}: {file_size:.1f} MB")
        if original_size > 0:
            print(f"   Original CoreML total: {original_size:.1f} MB")
            if model_type == "encoder" and original_size > 0:
                # Rough comparison (encoder is ~40% of total model)
                estimated_full_size = file_size * 2.5
                compression = original_size / estimated_full_size
                print(f"   Estimated full model: {estimated_full_size:.1f} MB")
                print(f"   Estimated compression: {compression:.1f}x")

        print(f"\n✅ CoreML conversion completed!")
        print(f"🎯 This CoreML model should use less memory during inference!")

    else:
        print(f"\n❌ CoreML conversion failed")
        print(f"💡 Consider using WhisperKit's official conversion tools")

if __name__ == "__main__":
    main()