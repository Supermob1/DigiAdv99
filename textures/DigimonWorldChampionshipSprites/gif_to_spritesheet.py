from PIL import Image, ImageSequence
import os

input_folder = "gifs"
output_folder = "spritesheets"

os.makedirs(output_folder, exist_ok=True)

for filename in os.listdir(input_folder):
    if filename.lower().endswith(".gif"):
        gif_path = os.path.join(input_folder, filename)
        base_name = os.path.splitext(filename)[0]
        gif = Image.open(gif_path)

        frames = [frame.convert("RGBA") for frame in ImageSequence.Iterator(gif)]
        w, h = frames[0].size
        sheet = Image.new("RGBA", (w * len(frames), h))

        for i, frame in enumerate(frames):
            sheet.paste(frame, (i * w, 0))

        output_path = os.path.join(output_folder, f"{base_name}.png")
        sheet.save(output_path)
        print(f"✅ {filename} → {output_path}")
