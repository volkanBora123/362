# 📦 Video Compression Project (CMPE362)

This project implements a block-based video compression and decompression pipeline in MATLAB. It features two compression algorithms:


## ⚙️ Requirements

- MATLAB R2020 or later
- No additional toolboxes required

---

## 🚀 How to Run

1. Place input `.jpg` frames in the `video_data/` folder as `frame001.jpg`, `frame002.jpg`, etc.
2. Run either compression script:
    ```matlab
    compress(15);              % Simple algorithm
    improved_compress(15);     % Improved algorithm
    ```
3. Then decompress:
    ```matlab
    decompress(15);
    improved_decompress();
    ```
4. Reconstructed frames will be in `./decompressed/` or `./decompressed_frames/`.

