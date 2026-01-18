
from PIL import Image

def remove_background_floodfill(input_path, tolerance=30):
    try:
        img = Image.open(input_path)
        img = img.convert("RGBA")
        width, height = img.size
        
        # Get data as a list of pixels to modify
        pixels = img.load()
        
        # Helper to check if a pixel is "white-ish"
        def is_white(r, g, b, a):
            return r > (255 - tolerance) and g > (255 - tolerance) and b > (255 - tolerance) and a == 255

        # Flood fill from all 4 corners
        # We use a set of visited coordinates to avoid loops
        queue = [(0, 0), (width-1, 0), (0, height-1), (width-1, height-1)]
        visited = set(queue)
        
        # Directions: Up, Down, Left, Right
        moves = [(0, 1), (0, -1), (1, 0), (-1, 0)]
        
        while queue:
            x, y = queue.pop(0)
            
            # Check if this pixel is white
            r, g, b, a = pixels[x, y]
            if is_white(r, g, b, a):
                # Make transparent
                pixels[x, y] = (255, 255, 255, 0)
                
                # Check neighbors
                for dx, dy in moves:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in visited:
                        visited.add((nx, ny))
                        queue.append((nx, ny))
            else:
                # If we hit a non-white pixel (the purple logo), stop this branch
                pass

        img.save(input_path, "PNG")
        print(f"Successfully processed {input_path} with flood fill")
        
    except Exception as e:
        print(f"Error processing {input_path}: {e}")

# Process favicon (usually small, corner transparency works)
# remove_background_floodfill('web/favicon.png')
# User requested to keep favicon as is.

# Process Icon-192 
# Note: If the white border is detached from the purple square, flood fill works perfect.
# If the purple square touches the edge, we hopefully only remove the corners.
remove_background_floodfill('web/icons/Icon-192.png')
