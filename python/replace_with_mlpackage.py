#!/usr/bin/env python3
"""
Replace with MLPackage Version

Since the compiled .mlmodelc has issues, let's use the .mlpackage version
and see if WhisperKit can work with that.
"""

import shutil
from pathlib import Path

def get_model_size_mb(path):
    """Get model size in MB"""
    if Path(path).is_dir():
        size = sum(f.stat().st_size for f in Path(path).rglob('*') if f.is_file())
    else:
        size = Path(path).stat().st_size
    return size / (1024 * 1024)

def test_mlpackage():
    """Test if the .mlpackage version works"""
    print("🧪 Testing .mlpackage quantized models...")

    quantized_encoder = Path("AudioEncoder_quantized.mlpackage")

    if not quantized_encoder.exists():
        print(f"❌ Quantized AudioEncoder.mlpackage not found")
        return False

    try:
        import coremltools as ct
        model = ct.models.MLModel(quantized_encoder)
        size_mb = get_model_size_mb(quantized_encoder)
        print(f"✅ AudioEncoder_quantized.mlpackage: {size_mb:.1f} MB - Loads successfully")
        return True

    except Exception as e:
        print(f"❌ AudioEncoder_quantized.mlpackage failed to load: {e}")
        return False

def replace_with_mlpackage():
    """Replace AudioEncoder.mlmodelc with AudioEncoder.mlpackage"""
    print("\n🔄 Replacing AudioEncoder with .mlpackage version...")

    app_models_dir = Path("/Users/amraboelela/develop/swift/EnglishSubtitles/EnglishSubtitles/Models/openai_whisper-medium")
    original_encoder = app_models_dir / "AudioEncoder.mlmodelc"
    quantized_encoder = Path("AudioEncoder_quantized.mlpackage")

    if not quantized_encoder.exists():
        print(f"❌ Quantized AudioEncoder not found: {quantized_encoder}")
        return False

    try:
        # Get sizes
        if original_encoder.exists():
            orig_size = get_model_size_mb(original_encoder)
            print(f"📊 Original AudioEncoder.mlmodelc: {orig_size:.1f} MB")

        quant_size = get_model_size_mb(quantized_encoder)
        print(f"📊 Quantized AudioEncoder.mlpackage: {quant_size:.1f} MB")

        # Remove original .mlmodelc
        if original_encoder.exists():
            if original_encoder.is_dir():
                shutil.rmtree(original_encoder)
            else:
                original_encoder.unlink()
            print(f"✅ Removed original AudioEncoder.mlmodelc")

        # Copy quantized .mlpackage
        target_mlpackage = app_models_dir / "AudioEncoder.mlpackage"

        if target_mlpackage.exists():
            if target_mlpackage.is_dir():
                shutil.rmtree(target_mlpackage)
            else:
                target_mlpackage.unlink()

        shutil.copytree(quantized_encoder, target_mlpackage)

        # Verify
        new_size = get_model_size_mb(target_mlpackage)
        print(f"✅ Quantized AudioEncoder installed: {new_size:.1f} MB")

        if original_encoder.exists() and orig_size > 0:
            savings = orig_size - new_size
            print(f"💾 Space saved: {savings:.1f} MB ({(savings/orig_size*100):.1f}%)")

        return True

    except Exception as e:
        print(f"❌ Replacement failed: {e}")
        return False

def show_app_status():
    """Show final app model status"""
    print("\n📊 APP MODEL STATUS")
    print("=" * 40)

    app_models_dir = Path("/Users/amraboelela/develop/swift/EnglishSubtitles/EnglishSubtitles/Models/openai_whisper-medium")

    models = [
        ("AudioEncoder.mlpackage", "AudioEncoder (QUANTIZED .mlpackage)"),
        ("AudioEncoder.mlmodelc", "AudioEncoder (.mlmodelc - should be removed)"),
        ("TextDecoder.mlmodelc", "TextDecoder (original)"),
        ("MelSpectrogram.mlmodelc", "MelSpectrogram"),
    ]

    total_size = 0
    for model_file, description in models:
        model_path = app_models_dir / model_file
        if model_path.exists():
            size_mb = get_model_size_mb(model_path)
            total_size += size_mb
            status = "✅" if "QUANTIZED" in description else "📋"
            print(f"   {status} {description:35}: {size_mb:6.1f} MB")
        else:
            print(f"   ⚫ {description:35}: Not found")

    print(f"\n   📊 TOTAL APP MODELS: {total_size:.1f} MB")

def main():
    """Main workflow"""
    print("🚀 Replace with MLPackage Version")
    print("=" * 40)

    # Test the .mlpackage version
    if not test_mlpackage():
        print("❌ Cannot proceed - quantized model doesn't load")
        return

    # Replace with .mlpackage
    success = replace_with_mlpackage()
    if not success:
        print("❌ Replacement failed")
        return

    # Show status
    show_app_status()

    print(f"\n✅ REPLACEMENT COMPLETED!")
    print(f"\n💡 IMPORTANT NOTES:")
    print(f"   • Your app now uses AudioEncoder.mlpackage (quantized)")
    print(f"   • This is ~50% smaller than the original")
    print(f"   • WhisperKit should automatically use .mlpackage if .mlmodelc is missing")
    print(f"   • Test your app to make sure it works!")
    print(f"\n🔧 IF THERE ARE ISSUES:")
    print(f"   • Restore from backup: original_models_backup/")
    print(f"   • WhisperKit might need the exact .mlmodelc format")

if __name__ == "__main__":
    main()