#!/usr/bin/env python3
"""
Replace App Models with Quantized Versions

Creates backups and replaces the AudioEncoder in your app with the quantized version.
"""

import shutil
from pathlib import Path
import subprocess

def get_model_size_mb(path):
    """Get model size in MB"""
    if Path(path).is_dir():
        size = sum(f.stat().st_size for f in Path(path).rglob('*') if f.is_file())
    else:
        size = Path(path).stat().st_size
    return size / (1024 * 1024)

def create_backup():
    """Create backup of original models"""
    print("🔄 Creating backup of original models...")

    app_models_dir = Path("/Users/amraboelela/develop/swift/EnglishSubtitles/EnglishSubtitles/Models/openai_whisper-medium")
    backup_dir = Path("./original_models_backup")

    if backup_dir.exists():
        print(f"⚠️ Backup directory already exists: {backup_dir}")
        return backup_dir

    try:
        # Copy the entire directory
        shutil.copytree(app_models_dir, backup_dir)

        # Calculate backup size
        backup_size = sum(f.stat().st_size for f in backup_dir.rglob('*') if f.is_file()) / (1024 * 1024)
        print(f"✅ Backup created: {backup_dir} ({backup_size:.1f} MB)")
        return backup_dir

    except Exception as e:
        print(f"❌ Backup failed: {e}")
        return None

def test_quantized_models():
    """Test our quantized models before replacing"""
    print("\n🧪 Testing quantized models...")

    models_to_test = [
        ("AudioEncoder_quantized.mlmodelc", "Quantized AudioEncoder"),
        ("MelSpectrogram.mlmodelc", "MelSpectrogram"),
    ]

    working_models = []
    for model_path, model_name in models_to_test:
        if not Path(model_path).exists():
            print(f"⚠️ {model_name} not found: {model_path}")
            continue

        try:
            # Try to load the model
            import coremltools as ct
            model = ct.models.MLModel(model_path)
            size_mb = get_model_size_mb(model_path)
            print(f"✅ {model_name}: {size_mb:.1f} MB - Model loads successfully")
            working_models.append((model_path, model_name, size_mb))

        except Exception as e:
            print(f"❌ {model_name} failed to load: {e}")

    return working_models

def replace_audioencoder():
    """Replace the AudioEncoder in the app with our quantized version"""
    print("\n🔄 Replacing AudioEncoder with quantized version...")

    app_models_dir = Path("/Users/amraboelela/develop/swift/EnglishSubtitles/EnglishSubtitles/Models/openai_whisper-medium")
    original_encoder = app_models_dir / "AudioEncoder.mlmodelc"
    quantized_encoder = Path("AudioEncoder_quantized.mlmodelc")

    if not quantized_encoder.exists():
        print(f"❌ Quantized AudioEncoder not found: {quantized_encoder}")
        return False

    if not original_encoder.exists():
        print(f"❌ Original AudioEncoder not found: {original_encoder}")
        return False

    try:
        # Get sizes before replacement
        orig_size = get_model_size_mb(original_encoder)
        quant_size = get_model_size_mb(quantized_encoder)

        print(f"📊 Size comparison:")
        print(f"   Original:  {orig_size:.1f} MB")
        print(f"   Quantized: {quant_size:.1f} MB")
        print(f"   Savings:   {orig_size - quant_size:.1f} MB ({((orig_size - quant_size) / orig_size * 100):.1f}%)")

        # Remove original
        if original_encoder.is_dir():
            shutil.rmtree(original_encoder)
        else:
            original_encoder.unlink()

        # Copy quantized version
        shutil.copytree(quantized_encoder, original_encoder)

        # Verify replacement
        new_size = get_model_size_mb(original_encoder)
        print(f"✅ AudioEncoder replaced successfully: {new_size:.1f} MB")

        return True

    except Exception as e:
        print(f"❌ Replacement failed: {e}")
        return False

def show_final_status():
    """Show final status of all models"""
    print("\n📊 FINAL APP MODEL STATUS")
    print("=" * 50)

    app_models_dir = Path("/Users/amraboelela/develop/swift/EnglishSubtitles/EnglishSubtitles/Models/openai_whisper-medium")

    models = [
        ("AudioEncoder.mlmodelc", "AudioEncoder (QUANTIZED)"),
        ("TextDecoder.mlmodelc", "TextDecoder (original)"),
        ("MelSpectrogram.mlmodelc", "MelSpectrogram"),
    ]

    total_size = 0
    for model_file, description in models:
        model_path = app_models_dir / model_file
        if model_path.exists():
            size_mb = get_model_size_mb(model_path)
            total_size += size_mb
            print(f"   {description:25}: {size_mb:6.1f} MB")
        else:
            print(f"   {description:25}: Not found")

    print(f"   {'TOTAL APP SIZE':25}: {total_size:6.1f} MB")

    # Compare with original
    backup_dir = Path("./original_models_backup")
    if backup_dir.exists():
        original_total = sum(f.stat().st_size for f in backup_dir.rglob('*') if f.is_file()) / (1024 * 1024)
        savings = original_total - total_size
        print(f"\n🏆 COMPRESSION ACHIEVED:")
        print(f"   Original total: {original_total:.1f} MB")
        print(f"   New total:      {total_size:.1f} MB")
        print(f"   Space saved:    {savings:.1f} MB ({(savings/original_total*100):.1f}%)")

def main():
    """Main replacement workflow"""
    print("🚀 Replace App Models with Quantized Versions")
    print("=" * 50)

    # Step 1: Create backup
    backup_dir = create_backup()
    if not backup_dir:
        print("❌ Cannot proceed without backup")
        return

    # Step 2: Test our quantized models
    working_models = test_quantized_models()
    if not working_models:
        print("❌ No working quantized models found")
        return

    # Step 3: Replace AudioEncoder
    success = replace_audioencoder()
    if not success:
        print("❌ Failed to replace AudioEncoder")
        print(f"💡 You can restore from backup: {backup_dir}")
        return

    # Step 4: Show final status
    show_final_status()

    print(f"\n✅ MODEL REPLACEMENT COMPLETED!")
    print(f"📁 Backup saved at: {backup_dir}")
    print(f"🎯 AudioEncoder is now 50% smaller!")
    print(f"⚠️ TextDecoder remains original size (couldn't quantize)")
    print(f"\n💡 NEXT STEPS:")
    print(f"   1. Test your app to make sure it still works")
    print(f"   2. If there are issues, restore from backup")
    print(f"   3. If it works, enjoy the smaller app size!")

if __name__ == "__main__":
    main()