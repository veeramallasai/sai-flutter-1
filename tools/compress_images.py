import os
from PIL import Image

def compress_images(directory):
    count = 0
    total_saved = 0
    for root, _, files in os.walk(directory):
        for file in files:
            if file.lower().endswith(('.png', '.jpg', '.jpeg')):
                path = os.path.join(root, file)
                try:
                    orig_size = os.path.getsize(path)
                    with Image.open(path) as img:
                        img.thumbnail((400, 400), Image.Resampling.LANCZOS)
                        img.save(path, optimize=True)
                    new_size = os.path.getsize(path)
                    saved = orig_size - new_size
                    total_saved += saved
                    count += 1
                    print(f"[{count}] {file}: {orig_size//1024}KB -> {new_size//1024}KB")
                except Exception as e:
                    print(f"Error {file}: {e}")
    print(f"\nCompression complete! Total saved: {total_saved / (1024*1024):.2f} MB")

if __name__ == '__main__':
    compress_images('assets/images')
