
from PIL import Image
import os

def remove_white_background(input_path):
    try:
        img = Image.open(input_path)
        img = img.convert("RGBA")
        datas = img.getdata()

        newData = []
        for item in datas:
            # Change all white (also shades of whites)
            # to transparent
            if item[0] > 240 and item[1] > 240 and item[2] > 240:
                newData.append((255, 255, 255, 0))
            else:
                newData.append(item)

        img.putdata(newData)
        img.save(input_path, "PNG")
        print(f"Successfully processed {input_path}")
    except Exception as e:
        print(f"Error processing {input_path}: {e}")

# Process favicon
remove_white_background('web/favicon.png')
# Process Icon-192 just in case, though we used border-radius there
remove_white_background('web/icons/Icon-192.png')
