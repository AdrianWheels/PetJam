import os
from PIL import Image, ImageFilter, ImageOps

def thicken_outline(image_path, thickness=3):
    """
    Thickens the outline of an image by creating a dilated mask of the non-transparent areas.
    """
    try:
        with Image.open(image_path) as img:
            if img.mode != 'RGBA':
                img = img.convert('RGBA')
            
            # Extract the alpha channel
            alpha = img.split()[3]
            
            # Create a mask of the non-transparent pixels
            # A simple way to thicken is to use a MaxFilter (Dilation)
            # We use a filter with size based on thickness. 
            # Pillow's MaxFilter works on the alpha channel.
            thick_alpha = alpha.filter(ImageFilter.MaxFilter(thickness * 2 + 1))
            
            # Create a new white image (the outline color) with the thick alpha
            outline = Image.new('RGBA', img.size, (255, 255, 255, 255))
            outline.putalpha(thick_alpha)
            
            # Composite original image over the outline
            combined = Image.alpha_composite(outline, img)
            
            # Save it back to the same path
            combined.save(image_path)
            print(f"Processed: {image_path}")
            
    except Exception as e:
        print(f"Error processing {image_path}: {e}")

def process_directory(directory, thickness=3):
    for filename in os.listdir(directory):
        if filename.lower().endswith('.png'):
            path = os.path.join(directory, filename)
            thicken_outline(path, thickness)

if __name__ == "__main__":
    directories = [
        r"D:\Proyectos\PetJam\art\assets\Imagenes\Items",
        r"D:\Proyectos\PetJam\art\assets\Imagenes\Materials",
        r"D:\Proyectos\PetJam\art\assets\Imagenes\Menu"
    ]
    
    # Using thickness 9 (3 original + 6 more as requested).
    outline_thickness = 9
    
    for dir_path in directories:
        if os.path.exists(dir_path):
            print(f"Processing directory: {dir_path}")
            process_directory(dir_path, outline_thickness)
        else:
            print(f"Directory not found: {dir_path}")
