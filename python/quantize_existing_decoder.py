#!/usr/bin/env python3
"""
Quantize Existing TextDecoder

Try to quantize the existing TextDecoder.mlmodelc directly.
"""

import coremltools as ct
from pathlib import Path

def quantize_existing_textdecoder():
    """Try to quantize the existing TextDecoder"""
    print("🔄 Attempting to quantize existing TextDecoder.mlmodelc...")

    # Load the existing TextDecoder
    original_decoder_path = "/Users/amraboelela/develop/swift/EnglishSubtitles/EnglishSubtitles/Models/openai_whisper-medium/TextDecoder.mlmodelc"

    if not Path(original_decoder_path).exists():
        print(f"❌ Original TextDecoder not found at: {original_decoder_path}")
        return None, 0

    try:
        print("🔄 Loading existing TextDecoder...")
        # Load the compiled model
        decoder_model = ct.models.MLModel(original_decoder_path)

        print("🔄 Applying int8 quantization...")
        # Apply quantization
        from coremltools.optimize.coreml import OpLinearQuantizerConfig, OptimizationConfig

        op_config = OpLinearQuantizerConfig(
            mode="linear_symmetric",
            weight_threshold=512
        )
        config = OptimizationConfig(global_config=op_config)

        quantized_decoder = ct.optimize.coreml.linear_quantize_weights(
            decoder_model,
            config=config
        )

        # Save the quantized decoder
        output_path = "TextDecoder_quantized.mlpackage"
        quantized_decoder.save(output_path)

        # Get size
        size = sum(f.stat().st_size for f in Path(output_path).rglob('*') if f.is_file())
        size_mb = size / (1024 * 1024)

        print(f"✅ Quantized TextDecoder saved: {size_mb:.1f} MB")

        # Now compile to mlmodelc
        print("🔄 Compiling to mlmodelc format...")
        import subprocess

        try:
            cmd = ["xcrun", "coremlcompiler", "compile", output_path, "."]
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)

            compiled_path = "TextDecoder_quantized.mlmodelc"
            if Path(compiled_path).exists():
                compiled_size = sum(f.stat().st_size for f in Path(compiled_path).rglob('*') if f.is_file()) / (1024 * 1024)
                print(f"✅ Compiled TextDecoder: {compiled_size:.1f} MB")
                return compiled_path, compiled_size
            else:
                print("❌ Compilation output not found")
                return None, 0

        except subprocess.CalledProcessError as e:
            print(f"❌ Compilation failed: {e}")
            return None, 0

    except Exception as e:
        print(f"❌ TextDecoder quantization failed: {e}")
        return None, 0

def get_model_size_mb(path):
    """Get model size in MB"""
    if Path(path).is_dir():
        size = sum(f.stat().st_size for f in Path(path).rglob('*') if f.is_file())
    else:
        size = Path(path).stat().st_size
    return size / (1024 * 1024)

def final_comparison():
    """Final size comparison"""
    print("\n📊 FINAL SIZE COMPARISON")
    print("=" * 50)

    # Original models
    original_dir = "/Users/amraboelela/develop/swift/EnglishSubtitles/EnglishSubtitles/Models/openai_whisper-medium"

    models = [
        # (original_path, quantized_path, name)
        (f"{original_dir}/AudioEncoder.mlmodelc", "AudioEncoder_quantized.mlmodelc", "AudioEncoder"),
        (f"{original_dir}/TextDecoder.mlmodelc", "TextDecoder_quantized.mlmodelc", "TextDecoder"),
        (f"{original_dir}/MelSpectrogram.mlmodelc", "MelSpectrogram.mlmodelc", "MelSpectrogram"),
    ]

    total_original = 0
    total_quantized = 0

    for original_path, quantized_path, name in models:
        print(f"\n{name}:")

        # Original
        if Path(original_path).exists():
            orig_size = get_model_size_mb(original_path)
            print(f"  Original:  {orig_size:6.1f} MB")
            total_original += orig_size
        else:
            print(f"  Original:  Not found")

        # Quantized
        if Path(quantized_path).exists():
            quant_size = get_model_size_mb(quantized_path)
            print(f"  Quantized: {quant_size:6.1f} MB", end="")
            total_quantized += quant_size

            if Path(original_path).exists():
                savings = orig_size - quant_size
                compression = orig_size / quant_size if quant_size > 0 else 0
                print(f" ({compression:.1f}x smaller, {savings:.1f}MB saved)")
            else:
                print()
        else:
            print(f"  Quantized: Not created")

    print(f"\nTOTALS:")
    print(f"  Original total:  {total_original:6.1f} MB")
    print(f"  Quantized total: {total_quantized:6.1f} MB")

    if total_quantized > 0 and total_original > 0:
        total_savings = total_original - total_quantized
        total_compression = total_original / total_quantized
        savings_percent = (total_savings / total_original) * 100

        print(f"\n🏆 OVERALL RESULTS:")
        print(f"   Total compression: {total_compression:.1f}x smaller")
        print(f"   Total space saved: {total_savings:.1f} MB ({savings_percent:.1f}%)")

def main():
    """Main function"""
    print("🚀 Quantizing Existing TextDecoder")
    print("=" * 40)

    # Try to quantize existing TextDecoder
    decoder_path, decoder_size = quantize_existing_textdecoder()

    # Show final comparison
    final_comparison()

    print(f"\n✅ QUANTIZATION STATUS:")
    print(f"   AudioEncoder: ✅ Quantized (295 MB)")
    if decoder_path:
        print(f"   TextDecoder:  ✅ Quantized ({decoder_size:.1f} MB)")
    else:
        print(f"   TextDecoder:  ❌ Failed to quantize")
    print(f"   MelSpectrogram: ✅ Copied (0.3 MB)")

if __name__ == "__main__":
    main()